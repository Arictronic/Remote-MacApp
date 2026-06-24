import asyncio
import os
from pathlib import Path
from typing import Optional, Set, Tuple, Union

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import FileResponse, JSONResponse, PlainTextResponse, RedirectResponse


def load_env_file(path: Path) -> None:
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()

        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")

        if key and key not in os.environ:
            os.environ[key] = value


BASE_DIR = Path(__file__).resolve().parent.parent
SERVER_DIR = Path(__file__).resolve().parent
VIEWER_DIR = SERVER_DIR / "viewer"
VIEWER_INDEX = VIEWER_DIR / "index.html"

load_env_file(SERVER_DIR / ".env")

TOKEN = os.environ.get("RMA_TOKEN", "change-me-123")
DEFAULT_TOKEN = TOKEN == "change-me-123"

if DEFAULT_TOKEN:
    print("WARNING: default token is used. Change RMA_TOKEN in server/.env before exposing the server.")

app = FastAPI(title="Remote Mac Access Relay")

Payload = Tuple[str, Union[bytes, str]]

mac_socket: Optional[WebSocket] = None
viewers: Set["ViewerClient"] = set()
lock = asyncio.Lock()


class ViewerClient:
    def __init__(self, ws: WebSocket):
        self.ws = ws
        self.queue: asyncio.Queue[Payload] = asyncio.Queue(maxsize=1)
        self.sender_task: Optional[asyncio.Task] = None

    def enqueue_latest(self, item: Payload) -> None:
        if self.queue.full():
            try:
                self.queue.get_nowait()
            except asyncio.QueueEmpty:
                pass

        try:
            self.queue.put_nowait(item)
        except asyncio.QueueFull:
            pass


async def viewer_sender(client: ViewerClient) -> None:
    try:
        while True:
            kind, payload = await client.queue.get()

            if kind == "bytes":
                await client.ws.send_bytes(payload)  # type: ignore[arg-type]
            else:
                await client.ws.send_text(payload)  # type: ignore[arg-type]
    except Exception:
        pass
    finally:
        async with lock:
            viewers.discard(client)


def token_ok(ws: WebSocket) -> bool:
    return ws.query_params.get("token") == TOKEN


def request_token_ok(request: Request) -> bool:
    token = request.query_params.get("token") or request.cookies.get("rma_token")
    return token == TOKEN


def token_from_request(request: Request) -> str:
    return request.query_params.get("token") or request.cookies.get("rma_token") or ""


@app.middleware("http")
async def http_guard(request: Request, call_next):
    path = request.url.path.rstrip("/") or "/"
    public_paths = {"/", "/viewer"}
    protected_paths = {"/health"}

    if path not in public_paths and path not in protected_paths:
        return PlainTextResponse("Not found", status_code=404)

    if path in protected_paths and not request_token_ok(request):
        return PlainTextResponse("Forbidden", status_code=403)

    response = await call_next(request)

    token = request.query_params.get("token")
    if token == TOKEN:
        response.set_cookie("rma_token", TOKEN, httponly=True, samesite="strict")

    return response


async def broadcast(item: Payload) -> None:
    async with lock:
        current = list(viewers)

    for viewer in current:
        viewer.enqueue_latest(item)


async def send_to_mac(text: str) -> None:
    current_mac = mac_socket
    if current_mac is None:
        return

    try:
        await current_mac.send_text(text)
    except Exception:
        pass


async def notify_state() -> None:
    await broadcast(("text", f'{{"type":"server","mac_connected":{str(mac_socket is not None).lower()},"viewers":{len(viewers)},"default_token":{str(DEFAULT_TOKEN).lower()}}}'))


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "mac_connected": mac_socket is not None,
        "viewers": len(viewers),
        "default_token": DEFAULT_TOKEN,
    }


@app.get("/")
async def root():
    return RedirectResponse(url="/viewer/")


@app.get("/viewer")
@app.get("/viewer/")
async def viewer_page():
    return FileResponse(str(VIEWER_INDEX), media_type="text/html")


@app.websocket("/ws/mac")
async def ws_mac(ws: WebSocket):
    global mac_socket

    if not token_ok(ws):
        await ws.close(code=1008)
        return

    await ws.accept()

    async with lock:
        old = mac_socket
        mac_socket = ws

    if old is not None:
        try:
            await old.close(code=1012)
        except Exception:
            pass

    await notify_state()

    try:
        while True:
            msg = await ws.receive()

            if msg.get("type") == "websocket.disconnect":
                break

            data_bytes = msg.get("bytes")
            data_text = msg.get("text")

            if data_bytes is not None:
                await broadcast(("bytes", data_bytes))
            elif data_text is not None:
                await broadcast(("text", data_text))

    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        async with lock:
            if mac_socket is ws:
                mac_socket = None
        await notify_state()


@app.websocket("/ws/viewer")
async def ws_viewer(ws: WebSocket):
    if not token_ok(ws):
        await ws.close(code=1008)
        return

    await ws.accept()

    client = ViewerClient(ws)
    client.sender_task = asyncio.create_task(viewer_sender(client))

    async with lock:
        viewers.add(client)

    await notify_state()

    try:
        while True:
            data = await ws.receive_text()
            await send_to_mac(data)

    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        async with lock:
            viewers.discard(client)
        if client.sender_task:
            client.sender_task.cancel()
        await notify_state()

@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if "%RMA_HOST%"=="" set "RMA_HOST=0.0.0.0"
if "%RMA_PORT%"=="" set "RMA_PORT=8000"

set "RMA_NO_PAUSE=1"

if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env" >nul
        echo Created .env from .env.example
    ) else (
        echo RMA_TOKEN=change-me-123>".env"
        echo Created default .env
    )
)

if not exist ".venv\Scripts\python.exe" (
    call install_server.bat
    if errorlevel 1 (
        echo.
        echo Server install failed.
        pause
        exit /b 1
    )
)

".venv\Scripts\python.exe" -c "import uvicorn, fastapi" >nul 2>nul
if errorlevel 1 (
    echo Dependencies are missing or broken. Reinstalling...
    call install_server.bat
    if errorlevel 1 (
        echo.
        echo Server install failed.
        pause
        exit /b 1
    )
)

echo Remote Mac Access Server
echo Host:      %RMA_HOST%
echo Port:      %RMA_PORT%
echo Local:     http://127.0.0.1:%RMA_PORT%/viewer/
echo Health:    http://127.0.0.1:%RMA_PORT%/health?token=YOUR_TOKEN
echo LAN:       http://SERVER_LAN_IP:%RMA_PORT%/viewer/
echo.
echo If remote devices cannot connect, run open_firewall.bat as Administrator.
echo.

".venv\Scripts\python.exe" -m uvicorn main:app --host "%RMA_HOST%" --port "%RMA_PORT%"

echo.
echo Server stopped.
pause

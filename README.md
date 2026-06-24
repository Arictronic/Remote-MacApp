# Remote Mac Access

**Remote Mac Access** — self-hosted мини-проект для удалённого доступа к старому Mac через свой сервер и браузер.

Проект решает простую практическую задачу: получить доступ к Mac, для которого современные удалённые клиенты уже не подходят или работают нестабильно.  
Вместо стороннего сервиса используется свой relay-сервер, свой токен доступа и готовый Mac Agent.

Проверенная версия Mac:

```text
macOS 10.12.6 Sierra
```

На более новых версиях macOS проект отдельно не проверялся.

---

## Как это работает

```text
Mac Agent  ->  Windows/Python Server  ->  Browser Viewer
```

- **Mac Agent** запускается на Mac, снимает экран и принимает команды мыши/клавиатуры.
- **Server** принимает подключение Mac и viewer-а, передаёт кадры и команды между ними.
- **Viewer** открывается в браузере по ссылке сервера.

---

## Возможности

- просмотр экрана Mac в браузере;
- управление мышью;
- управление клавиатурой;
- горячие клавиши Mac;
- `Ctrl+C` / `Ctrl+V` с Windows как `Cmd+C` / `Cmd+V` на Mac;
- текстовый буфер обмена Windows ↔ Mac;
- отправка файлов с компьютера viewer-а на Mac;
- автопереподключение Mac Agent к серверу;
- настройка FPS/качества через `config.json`.

---

## Структура проекта

```text
remote-mac-access/
├── server/          серверная часть на Python/FastAPI
├── server/viewer/   браузерный viewer
├── mac_agent/       исходники Swift-агента
├── RemouteMacApp/   готовая Mac-сборка для запуска
├── README.md
└── .gitignore
```

Для обычного использования на Mac нужна именно папка:

```text
RemouteMacApp/
```

---

## Что нужно для работы

Нужен сервер, который доступен и Mac-у, и человеку, который открывает viewer.

Есть два варианта.

### Вариант 1 — сервер с белым IP

Подходит, если сервер запускается на компьютере с публичным IP-адресом.

Нужно:

- открыть TCP-порт `8000` в firewall;
- если сервер за роутером — пробросить порт `8000` на локальный IP сервера;
- в `RemouteMacApp/config.json` указать внешний адрес сервера.

Пример:

```json
"server": "ws://78.139.86.217:8000/ws/mac"
```

Viewer:

```text
http://78.139.86.217:8000/viewer/
```

### Вариант 2 — локальная сеть или VPN

Подходит, если сервер и Mac находятся в одной сети или VPN.

Нужно:

- сервер должен быть доступен по LAN/VPN IP;
- Mac должен видеть этот IP;
- VPN-клиент должен поддерживать macOS 10.12.6 Sierra, если используется старый Mac.

Пример:

```json
"server": "ws://192.168.10.3:8000/ws/mac"
```

---

## Запуск сервера

Требуется Python **3.11**.

На Windows:

```bat
cd server
start_server.bat
```

Скрипт автоматически:

- найдёт Python;
- создаст `.env` из `.env.example`, если `.env` отсутствует;
- создаст виртуальное окружение `.venv`;
- установит зависимости;
- запустит сервер на `0.0.0.0:8000`.

Проверка сервера:

```text
http://127.0.0.1:8000/health?token=YOUR_TOKEN
```

Viewer:

```text
http://127.0.0.1:8000/viewer/
```

---

## Настройка токена сервера

Файл:

```text
server/.env
```

Пример:

```env
RMA_TOKEN=your-token-here
```

Этот же токен должен быть указан на Mac в:

```text
RemouteMacApp/config.json
```

---

## Открытие порта на Windows

Можно запустить:

```bat
server/open_firewall.bat
```

Или выполнить PowerShell от имени администратора:

```powershell
New-NetFirewallRule -DisplayName "Remote Mac Access 8000 TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8000 -Profile Any
```

---

## Настройка Mac

На Mac используется готовая папка:

```text
RemouteMacApp/
```

Внутри:

```text
RemoteMacAgent
config.json
start_agent.command
```

Открой `config.json` и укажи адрес сервера и токен:

```json
{
  "server": "ws://SERVER_IP:8000/ws/mac",
  "token": "your-token-here",
  "fps": 24,
  "quality": 0.6,
  "max_width": 1600,
  "receive_dir": "Desktop",
  "skip_unchanged_frames": true,
  "send_unchanged_every_sec": 1.0
}
```

---

## Запуск Mac Agent

На Mac можно запустить двойным кликом:

```text
RemouteMacApp/start_agent.command
```

Скрипт сам запускает:

```text
RemoteMacAgent --config config.json
```

Если нужно запустить через Terminal:

```bash
cd "$HOME/Desktop/RemouteMacApp"
chmod +x RemoteMacAgent start_agent.command
./start_agent.command
```

Если macOS блокирует запуск после скачивания:

```bash
xattr -d com.apple.quarantine RemoteMacAgent
xattr -d com.apple.quarantine start_agent.command
chmod +x RemoteMacAgent start_agent.command
./start_agent.command
```

После запуска Mac Agent выведет ссылку viewer-а:

```text
Viewer connect URL: http://SERVER_IP:8000/viewer/?token=...
```

Открой эту ссылку в браузере, введи токен и нажми **Connect**.

---

## Разрешение управления на macOS

Для управления мышью и клавиатурой нужно разрешить доступ.

Открой:

```text
System Preferences -> Security & Privacy -> Privacy -> Accessibility
```

Добавь туда:

```text
Terminal
```

или:

```text
RemoteMacAgent
```

Без этого экран может передаваться, но управление может не работать.

---

## Качество изображения

Настройки в `config.json`:

```json
{
  "fps": 24,
  "quality": 0.6,
  "max_width": 1600
}
```

Для более плавного управления:

```json
{
  "fps": 30,
  "quality": 0.45,
  "max_width": 1440
}
```

Для более чёткой картинки:

```json
{
  "fps": 18,
  "quality": 0.72,
  "max_width": 1920
}
```

Если старый Mac тормозит:

```json
{
  "fps": 12,
  "quality": 0.4,
  "max_width": 1280
}
```

---

## Ограничения

- Это MVP-проект, а не промышленный remote desktop.
- Звук не передаётся.
- Передача файлов Mac → Windows пока не реализована.
- Файловый clipboard между Mac и Windows не синхронизируется.
- HTTPS/WSS не настроены из коробки.
- Основная проверенная система — macOS 10.12.6 Sierra.

---

## Сборка Mac Agent из исходников

Обычному пользователю это не нужно, потому что в проекте уже есть `RemouteMacApp/`.

Для самостоятельной сборки:

```bash
cd mac_agent
chmod +x build.sh
./build.sh
```

Для macOS 10.12.6 использовались:

```text
Xcode 9.2
Swift 4.0.3
```

---

## Идея проекта

Проект сделан как практическое решение ситуации, когда нужно подключиться к старому Mac, а готовые приложения удалённого доступа не подходят.

Идея простая:

```text
свой сервер
свой токен
свой Mac Agent
свой viewer в браузере
```

Минимум лишнего, полный контроль над подключением и понятная схема развёртывания.

@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo Remote Mac Access Server installer
echo.

if not exist ".env.example" (
    echo RMA_TOKEN=change-me-123>".env.example"
    echo Created .env.example
)

if not exist ".env" (
    copy ".env.example" ".env" >nul
    echo Created .env from .env.example
)

set "PYTHON_CMD="
call :try_python py -3.11
if not defined PYTHON_CMD call :try_python py -3
if not defined PYTHON_CMD call :try_python python
if not defined PYTHON_CMD call :try_python python3

if not defined PYTHON_CMD (
    echo ERROR: Python was not found.
    echo Install Python 3.11+ and enable "Add python.exe to PATH", or install Python Launcher.
    echo Download: https://www.python.org/downloads/windows/
    if /i not "%RMA_NO_PAUSE%"=="1" pause
    exit /b 1
)

echo Python command: %PYTHON_CMD%
%PYTHON_CMD% --version
if errorlevel 1 (
    echo ERROR: selected Python command failed.
    if /i not "%RMA_NO_PAUSE%"=="1" pause
    exit /b 1
)

if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" -c "import sys; print(sys.executable)" >nul 2>nul
    if errorlevel 1 (
        echo Existing .venv is broken. Removing it...
        rmdir /s /q ".venv"
    )
)

if not exist ".venv\Scripts\python.exe" (
    echo Creating virtual environment...
    %PYTHON_CMD% -m venv ".venv"
    if errorlevel 1 (
        echo ERROR: failed to create virtual environment.
        if /i not "%RMA_NO_PAUSE%"=="1" pause
        exit /b 1
    )
)

".venv\Scripts\python.exe" -c "import sys; print('Venv Python:', sys.executable)"
if errorlevel 1 (
    echo ERROR: virtual environment Python is not working.
    if /i not "%RMA_NO_PAUSE%"=="1" pause
    exit /b 1
)

echo Upgrading pip...
".venv\Scripts\python.exe" -m pip install --upgrade pip
if errorlevel 1 (
    echo ERROR: pip upgrade failed.
    if /i not "%RMA_NO_PAUSE%"=="1" pause
    exit /b 1
)

echo Installing requirements...
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: requirements installation failed.
    if /i not "%RMA_NO_PAUSE%"=="1" pause
    exit /b 1
)

".venv\Scripts\python.exe" -c "import uvicorn, fastapi; print('Server dependencies OK')"
if errorlevel 1 (
    echo ERROR: dependency check failed.
    if /i not "%RMA_NO_PAUSE%"=="1" pause
    exit /b 1
)

echo.
echo Installed successfully.
if /i not "%RMA_NO_PAUSE%"=="1" pause
exit /b 0

:try_python
if defined PYTHON_CMD exit /b 0
set "CANDIDATE=%*"
%CANDIDATE% -c "import sys; raise SystemExit(0 if sys.version_info >= (3,8) else 1)" >nul 2>nul
if not errorlevel 1 (
    set "PYTHON_CMD=%CANDIDATE%"
)
exit /b 0

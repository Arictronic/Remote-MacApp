@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Run this file as Administrator.
    pause
    exit /b 1
)

netsh advfirewall firewall add rule name="Remote Mac Access 8000 TCP" dir=in action=allow protocol=TCP localport=8000
netsh advfirewall firewall add rule name="Remote Mac Access Python" dir=in action=allow program="%~dp0.venv\Scripts\python.exe" protocol=TCP localport=8000

echo Firewall rules added.
pause

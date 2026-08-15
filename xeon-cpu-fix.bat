@echo off
REM Xeon CPU Fix - Main Wrapper Batch Script
REM This script wraps PowerShell functionality for easy execution

setlocal enabledelayedexpansion
cd /d "%~dp0"

REM Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: This script requires Administrator privileges.
    echo Please run Command Prompt as Administrator.
    pause
    exit /b 1
)

cls
echo ========================================
echo   Xeon CPU Fix Tool - Main Menu
echo ========================================
echo.
echo 1. Start CPU Monitoring (Real-time)
echo 2. Start Auto-balancing
echo 3. Start Both (Monitor + Balance)
echo 4. View Logs
echo 5. Edit Configuration
echo 6. Exit
echo.

set /p choice="Select option (1-6): "

if "%choice%"=="1" (
    cls
    echo Starting CPU Monitoring...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "windows\Monitor.ps1"
) else if "%choice%"=="2" (
    cls
    echo Starting CPU Auto-balancing...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "windows\AutoBalance.ps1"
) else if "%choice%"=="3" (
    cls
    echo Starting CPU Monitoring and Auto-balancing...
    echo.
    start "CPU Monitor" powershell -NoProfile -ExecutionPolicy Bypass -File "windows\Monitor.ps1"
    timeout /t 2 /nobreak
    start "CPU Balance" powershell -NoProfile -ExecutionPolicy Bypass -File "windows\AutoBalance.ps1"
    echo.
    echo Both services started in separate windows
    pause
) else if "%choice%"=="4" (
    cls
    echo.
    echo ========== CPU Fix Log ==========
    echo.
    if exist "logs\xeon-cpu-fix.log" (
        type "logs\xeon-cpu-fix.log"
    ) else (
        echo No logs found. Run monitoring or balancing first.
    )
    echo.
    pause
) else if "%choice%"=="5" (
    cls
    echo Opening Configuration File...
    notepad "config\config.yaml"
) else if "%choice%"=="6" (
    exit /b 0
) else (
    echo Invalid option. Please try again.
    timeout /t 2
    goto :main
)

cls
goto :eof

@echo off
setlocal enabledelayedexpansion

:: ---------- AUTO-ELEVATION ----------
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
:: ---------- END AUTO-ELEVATION ----------

echo Installing WSL and Ubuntu...
echo.

REM Install WSL
echo Installing Windows Subsystem for Linux...
wsl --install -d Ubuntu

if %errorLevel% equ 0 (
    echo.
    echo WSL and Ubuntu installation completed successfully!
    echo Please restart your computer to complete the installation.
) else (
    echo.
    echo Installation failed. Please check your system requirements.
)

pause

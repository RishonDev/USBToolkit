@echo off
setlocal enabledelayedexpansion

if "%1"=="" (
    echo Usage: unmountwin.cmd [drive_letter] [/h]
    echo Example: unmountwin.cmd E /h
    exit /b 1
)

if "%1"=="/h" (
    echo Unmount Script for Windows
    echo Usage: unmountwin.cmd [drive_letter] [/h]
    echo.
    echo Arguments:
    echo   drive_letter    The drive to unmount (e.g., E, F, G)
    echo   /h              Display this help message
    exit /b 0
)

set "drive=%1"

if "%2"=="/h" (
    echo Unmount Script for Windows
    echo Usage: unmountwin.cmd [drive_letter] [/h]
    echo.
    echo Arguments:
    echo   drive_letter    The drive to unmount (e.g., E, F, G)
    echo   /h              Display this help message
    exit /b 0
)

echo Attempting to unmount drive %drive%:
diskpart << EOF
list disk
EOF

echo.
echo Note: Use diskpart or third-party tools like usbdeview for USB ejection.
endlocal
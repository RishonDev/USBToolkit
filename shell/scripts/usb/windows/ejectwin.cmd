@echo off
setlocal enabledelayedexpansion

if "%1"=="" goto :show_help
if "%1"=="/h" goto :show_help
if "%1"=="/?" goto :show_help
if "%1"=="/e" goto :eject_drive

echo Invalid flag: %1
goto :show_help

:show_help
echo Usage: ejectwin.cmd [flags]
echo.
echo Flags:
echo   /h, /?    Show this help message
echo   /e        Eject the specified drive
echo.
echo Example: ejectwin.cmd /e D:
exit /b 0

:eject_drive
if "%2"=="" (
    echo Error: No drive letter specified
    echo Usage: ejectwin.cmd /e [drive letter]
    exit /b 1
)

set drive=%2
echo Ejecting drive %drive%...
powershell -Command "& { (New-Object -ComObject Shell.Application).Namespace(17).ParseName('%drive%').InvokeVerb('Eject') }"

if !errorlevel! equ 0 (
    echo Drive %drive% ejected successfully
) else (
    echo Failed to eject drive %drive%
    exit /b 1
)
exit /b 0
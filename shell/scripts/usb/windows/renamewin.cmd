@echo off
setlocal enabledelayedexpansion

REM Rename a Windows drive/partition
REM Usage: renamewin.cmd X: NewDriveName

if "%~1"=="" (
    echo Usage: renamewin.cmd DRIVE_LETTER NEW_NAME
    echo Example: renamewin.cmd D: BackupDrive
    exit /b 1
)

set "drive=%~1"
set "newname=%~2"

if "!newname!"=="" (
    echo Error: New drive name is required
    exit /b 1
)

REM Use label command to rename the drive
label %drive% %newname%

if %errorlevel% equ 0 (
    echo Drive %drive% renamed to: %newname%
) else (
    echo Error: Failed to rename drive %drive%
    exit /b 1
)

endlocal
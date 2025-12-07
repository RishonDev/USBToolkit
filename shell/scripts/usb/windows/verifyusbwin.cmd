if "%1"=="/h" (
    echo Usage: verifyusbwin.cmd [drive_letter]
    echo Example: verifyusbwin.cmd E:
    exit /b
)

if "%1"=="" (
    echo Error: No drive letter specified.
    echo Use /h for help.
    exit /b
)

chkdsk /f /R %1

@echo off

IF "%1" == "/h"
{
   echo "Usage: format_Windows.cmd FILESYSTEM_FORMAT DRIVE LETTER"
   echo "Replace FILESYSTEM_FORMAT with the format and RIVE_LETTER with the repective drive letter."
} 
format /FS:"%1" "%2%

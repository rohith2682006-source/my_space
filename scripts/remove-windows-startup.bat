@echo off
setlocal
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "STARTUP_FILE=%STARTUP_FOLDER%\spaces-pm2-startup.cmd"

if exist "%STARTUP_FILE%" (
    del /f /q "%STARTUP_FILE%"
    echo SUCCESS: Windows startup launcher removed: %STARTUP_FILE%
) else (
    echo Windows startup launcher was not installed.
)
endlocal

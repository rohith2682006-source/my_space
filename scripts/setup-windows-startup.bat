@echo off
setlocal
set "PROJECT_ROOT=%~dp0.."
cd /d "%PROJECT_ROOT%"

echo ================================================
echo   Configuring Windows Startup for Spaces
echo ================================================

echo Saving active PM2 processes...
call pm2 save

set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "STARTUP_FILE=%STARTUP_FOLDER%\spaces-pm2-startup.cmd"

echo @echo off > "%STARTUP_FILE%"
echo REM Auto-start Spaces services on Windows logon via PM2 resurrect >> "%STARTUP_FILE%"
echo echo Starting Spaces services... >> "%STARTUP_FILE%"
echo call pm2 resurrect >> "%STARTUP_FILE%"

echo.
echo SUCCESS: Windows startup registered!
echo Startup file created at:
echo   %STARTUP_FILE%
echo Whenever you log in to Windows, PM2 will automatically resurrect and run both services.
echo.
endlocal

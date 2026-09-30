@echo off
setlocal
set "PROJECT_ROOT=%~dp0.."
cd /d "%PROJECT_ROOT%"

echo Stopping all Spaces services managed by PM2...
call pm2 stop node-backend python-ai
call pm2 status
endlocal

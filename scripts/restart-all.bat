@echo off
setlocal
set "PROJECT_ROOT=%~dp0.."
cd /d "%PROJECT_ROOT%"

echo Rebuilding backend...
cd /d "%PROJECT_ROOT%\backend"
call npm run build
cd /d "%PROJECT_ROOT%"

echo Restarting all Spaces services managed by PM2...
call pm2 restart node-backend python-ai
call pm2 status
endlocal

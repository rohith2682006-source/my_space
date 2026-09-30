@echo off
setlocal
set "PROJECT_ROOT=%~dp0.."
cd /d "%PROJECT_ROOT%"

echo ========================================
echo   Starting Spaces Platform Services
echo ========================================

if not exist "%PROJECT_ROOT%\logs" (
    mkdir "%PROJECT_ROOT%\logs"
)

if not exist "%PROJECT_ROOT%\backend\dist\index.js" (
    echo Building Node.js backend...
    cd /d "%PROJECT_ROOT%\backend"
    call npm run build
    cd /d "%PROJECT_ROOT%"
)

call pm2 start ecosystem.config.js
call pm2 save
echo.
echo Current PM2 status:
call pm2 status
endlocal

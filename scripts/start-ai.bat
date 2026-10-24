@echo off
setlocal
set "PROJECT_ROOT=%~dp0.."
cd /d "%PROJECT_ROOT%\ai_service"
echo Starting Spaces Python AI service on port 8000...
call .venv\Scripts\python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
endlocal

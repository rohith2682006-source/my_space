# Spaces Platform — Windows Production & Setup Guide

This guide covers setting up, managing, and productionizing the **Spaces** platform on Windows using **PM2** to manage the Node.js backend and Python AI service independently with automatic crash recovery.

---

## Architecture Overview

```
                   Windows PC
                       │
                       ▼
                      PM2
                 ┌─────┴─────┐
                 │           │
                 ▼           ▼
            node-backend   python-ai
               :3000         :8000
                 │           │
                 └─────┬─────┘
                       ▼
                  OpenAI API
```

- **Node.js Backend**: Express + Prisma + SQLite on port `3000`
- **Python AI Service**: FastAPI + Uvicorn on port `8000`
- **Process Manager**: PM2 handles independent startup, health checks, log aggregation, and automatic crash recovery.

---

## 1. System Requirements

- **Operating System**: Windows 10 or Windows 11 (64-bit)
- **Node.js**: v18.0.0 or later (v20+ or v24 LTS recommended)
- **Python**: v3.11 or v3.12 (64-bit)
- **PowerShell**: Windows PowerShell 5.1+ or PowerShell 7+
- **PM2**: Global npm package (`npm install -g pm2`)

---

## 2. Node.js Installation

1. Download the LTS installer from [nodejs.org](https://nodejs.org/).
2. Run the installer and ensure **Add to PATH** is checked.
3. Verify installation in PowerShell:
   ```powershell
   node -v
   npm -v
   ```

---

## 3. Python Installation

1. Download Python 3.12 from [python.org](https://www.python.org/downloads/).
2. Run the installer and **check the box: "Add python.exe to PATH"**.
3. Verify in PowerShell:
   ```powershell
   python --version
   ```

---

## 4. Python Virtual Environment Setup

From the project root:
```powershell
cd ai_service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

If PowerShell gives an execution policy error, run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 5. Node.js Dependencies Installation & Build

1. Open PowerShell and navigate to `backend`:
   ```powershell
   cd backend
   npm install
   npm run db:generate
   npm run build
   ```
2. This creates `backend/dist/index.js` for production execution.

---

## 6. Python Dependencies Installation

From `ai_service`:
```powershell
cd ai_service
.\.venv\Scripts\pip install -r requirements.txt
```

---

## 7. Environment Variables

Each service uses its own `.env` file in its respective directory. Example templates are provided:

### Root Overview (`.env.example`)
Contains a combined reference of all core variables.

### Backend (`backend/.env`)
Copy `backend/.env.example` to `backend/.env` if not already present:
```env
PORT=3000
NODE_ENV=production
DATABASE_URL=file:./dev.db
AI_SERVICE_URL=http://127.0.0.1:8000
AI_SERVICE_TOKEN=your_shared_service_token
JWT_ACCESS_SECRET=your_super_secret_jwt_access_token_key_here_32chars
JWT_REFRESH_SECRET=your_super_secret_jwt_refresh_token_key_here_32chars
CORS_ORIGINS=http://localhost:3000
STORAGE_PROVIDER=local
UPLOAD_DIR=./uploads
MAX_FILE_SIZE_MB=500
```

### Python AI Service (`ai_service/.env`)
Copy `ai_service/.env.example` to `ai_service/.env` if not already present:
```env
OPENAI_API_KEY=your_openai_api_key_here
AI_SERVICE_TOKEN=your_shared_service_token
LLM_MODEL=gpt-4o-mini
EMBEDDING_MODEL=text-embedding-3-small
BACKEND_CALLBACK_URL=http://127.0.0.1:3000/api/v1/ai/internal/index-complete
```
> **Security Note**: Never commit `.env` files to Git. The `.gitignore` file is configured to keep all secrets safe.

---

## 8. Starting During Development (Manual Mode)

If you wish to run services manually with live hot-reloading during code development:

### Terminal 1 (Node.js Backend)
```powershell
cd backend
npm run dev
```

### Terminal 2 (Python AI Service)
```powershell
cd ai_service
.\.venv\Scripts\uvicorn.exe main:app --host 127.0.0.1 --port 8000 --reload
```

---

## 9. Starting with PM2 (Production Mode)

To run both services in the background with auto-restart:

### Quick Command (PowerShell or CMD)
```powershell
.\scripts\start-all.ps1
```
Or with Batch:
```cmd
scripts\start-all.bat
```

### Direct PM2 Command
```powershell
pm2 start ecosystem.config.js
pm2 save
```

This starts:
- `node-backend` on port `3000`
- `python-ai` on port `8000`

---

## 10. Checking Service Status

```powershell
.\scripts\status.ps1
# OR
pm2 status
```

Output displays:
```
┌────┬─────────────────┬─────────────┬─────────┬─────────┬──────────┬────────┬──────┬───────────┐
│ id │ name            │ namespace   │ version │ mode    │ pid      │ uptime │ ↺    │ status    │
├────┼─────────────────┼─────────────┼─────────┼─────────┼──────────┼────────┼──────┼───────────┤
│ 0  │ node-backend    │ default     │ 1.0.0   │ cluster │ 26648    │ 15m    │ 1    │ online    │
│ 1  │ python-ai       │ default     │ N/A     │ fork    │ 20868    │ 15m    │ 1    │ online    │
└────┴─────────────────┴─────────────┴─────────┴─────────┴──────────┴────────┴──────┴───────────┘
```

---

## 11. Viewing Logs

### Real-Time Streaming
```powershell
.\scripts\logs.ps1
# OR
pm2 logs
```

### Specific Service Logs
```powershell
pm2 logs node-backend
pm2 logs python-ai
```

### Log File Locations
All application output and error logs are stored in:
- `logs/node-backend-out.log`
- `logs/node-backend-error.log`
- `logs/python-ai-out.log`
- `logs/python-ai-error.log`

---

## 12. Restarting Services

### Restart All Services
```powershell
.\scripts\restart-all.ps1
# OR
pm2 restart all
```

### Restart a Single Service
```powershell
pm2 restart node-backend
pm2 restart python-ai
```

---

## 13. Stopping Services

### Stop All Services
```powershell
.\scripts\stop-all.ps1
# OR
pm2 stop all
```

### Delete/Remove from PM2
```powershell
pm2 delete all
```

---

## 14. Configuring Automatic Windows Startup

To ensure both services start automatically when your computer turns on or reboots:

### Method 1: Using the Included Script (Recommended & Free)
Run:
```powershell
.\scripts\setup-windows-startup.ps1
```
This saves the PM2 process list (`pm2 save`) and registers a startup script in your Windows Startup directory (`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\spaces-pm2-startup.cmd`). On Windows login, it calls `pm2 resurrect` to instantly bring up both services.

To remove Windows auto-startup later:
```powershell
.\scripts\remove-windows-startup.ps1
```

### Method 2: Windows Task Scheduler
1. Open **Task Scheduler** (`taskschd.msc`).
2. Click **Create Basic Task**.
3. Name: `Spaces-PM2-Startup`.
4. Trigger: **When I log on**.
5. Action: **Start a program**.
6. Program: `pm2.cmd` (or full path to `npm\pm2.cmd`).
7. Arguments: `resurrect`.
8. Save the task.

---

## 15. Troubleshooting Port 3000

If `node-backend` fails to start because port 3000 is occupied:

1. Check what process is using port 3000:
   ```powershell
   Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue | Select-Object LocalPort, OwningProcess, State
   ```
2. Terminate the blocking process by its PID:
   ```powershell
   Stop-Process -Id <OwningProcessPID> -Force
   ```
3. Restart the backend:
   ```powershell
   pm2 restart node-backend
   ```

---

## 16. Troubleshooting Port 8000

If `python-ai` fails to bind to port 8000:

1. Identify the process listening on port 8000:
   ```powershell
   Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue | Select-Object LocalPort, OwningProcess, State
   ```
2. Stop the blocking process:
   ```powershell
   Stop-Process -Id <OwningProcessPID> -Force
   ```
3. Restart the Python AI service:
   ```powershell
   pm2 restart python-ai
   ```

---

## 17. Troubleshooting OpenAI API Errors

The platform distinguishes between errors and provides user-friendly status responses:

| Status Code | Error Code | Meaning & Resolution |
|---|---|---|
| **401** | `AI_AUTH_ERROR` | **Invalid or Missing API Key**. Check `ai_service/.env` and verify `OPENAI_API_KEY` is set correctly without whitespace or quotes. |
| **402** | `AI_QUOTA_EXHAUSTED` | **Billing / Credit Limit Exhausted**. Your OpenAI account has zero remaining credits. Visit [OpenAI Billing](https://platform.openai.com/settings/organization/billing/) to add prepaid credits. The service will gracefully notify users without crashing. |
| **429** | `AI_RATE_LIMITED` | **Rate Limit Hit**. Too many requests per minute/day. Wait 30-60 seconds before retrying. |
| **502** | `AI_PROVIDER_ERROR` | **OpenAI Upstream Error**. OpenAI servers experienced an outage or network error. |
| **503** | `AI_UNAVAILABLE` | **Python AI Service Offline**. Verify `python-ai` status with `pm2 status` and check `logs/python-ai-error.log`. |
| **504** | `AI_TIMEOUT` | **Request Timed Out**. The request took longer than 30 seconds. Check document size or network latency. |

---

## Summary of Essential Commands

| Action | PowerShell Script | Native PM2 Command |
|---|---|---|
| **Start All** | `.\scripts\start-all.ps1` | `pm2 start ecosystem.config.js` |
| **Check Status** | `.\scripts\status.ps1` | `pm2 status` |
| **View Logs** | `.\scripts\logs.ps1` | `pm2 logs` |
| **Restart** | `.\scripts\restart-all.ps1` | `pm2 restart all` |
| **Stop All** | `.\scripts\stop-all.ps1` | `pm2 stop all` |

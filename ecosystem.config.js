const path = require('path');

module.exports = {
  apps: [
    {
      name: 'node-backend',
      cwd: path.resolve(__dirname, 'backend'),
      script: 'dist/index.js',
      instances: 1,
      autorestart: true,
      watch: false,
      max_restarts: 10,
      restart_delay: 3000,
      min_uptime: '5s',
      kill_timeout: 5000,
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      error_file: path.resolve(__dirname, 'logs/node-backend-error.log'),
      out_file: path.resolve(__dirname, 'logs/node-backend-out.log'),
      combine_logs: true,
      time: true,
    },
    {
      name: 'python-ai',
      cwd: path.resolve(__dirname, 'ai_service'),
      script: path.resolve(__dirname, 'ai_service/.venv/Scripts/python.exe'),
      args: '-m uvicorn main:app --host 127.0.0.1 --port 8000',
      interpreter: 'none',
      instances: 1,
      autorestart: true,
      watch: false,
      max_restarts: 10,
      restart_delay: 3000,
      min_uptime: '5s',
      kill_timeout: 5000,
      env: {
        LOG_LEVEL: 'INFO',
      },
      error_file: path.resolve(__dirname, 'logs/python-ai-error.log'),
      out_file: path.resolve(__dirname, 'logs/python-ai-out.log'),
      combine_logs: true,
      time: true,
    },
  ],
};

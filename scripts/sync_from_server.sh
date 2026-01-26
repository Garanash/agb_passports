#!/bin/bash
SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

echo "🔄 Синхронизация файлов с сервера..."

sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$SERVER:$SERVER_PATH/frontend/pages/login.tsx" \
  "$LOCAL_PATH/frontend/pages/" 2>&1 | grep -v "Warning"

sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$SERVER:$SERVER_PATH/frontend/components/MainApp.tsx" \
  "$LOCAL_PATH/frontend/components/" 2>&1 | grep -v "Warning"

sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$SERVER:$SERVER_PATH/frontend/hooks/usePassports.ts" \
  "$LOCAL_PATH/frontend/hooks/" 2>&1 | grep -v "Warning"

sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$SERVER:$SERVER_PATH/frontend/lib/api.ts" \
  "$LOCAL_PATH/frontend/lib/" 2>&1 | grep -v "Warning"

sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$SERVER:$SERVER_PATH/backend/utils/pdf_generator.py" \
  "$LOCAL_PATH/backend/utils/pdf_generator.py" 2>&1 | grep -v "Warning"

echo "✅ Синхронизация завершена"

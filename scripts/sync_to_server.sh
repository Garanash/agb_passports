#!/bin/bash
# Скрипт для синхронизации локальных файлов на сервер

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

echo "🔄 Синхронизация файлов на сервер..."

# Frontend файлы
echo "📦 Синхронизация frontend..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/frontend/pages/login.tsx" \
  "$SERVER:$SERVER_PATH/frontend/pages/" 2>&1 | grep -v "Warning"

sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/frontend/components/MainApp.tsx" \
  "$SERVER:$SERVER_PATH/frontend/components/" 2>&1 | grep -v "Warning"

sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/frontend/hooks/usePassports.ts" \
  "$SERVER:$SERVER_PATH/frontend/hooks/" 2>&1 | grep -v "Warning"

sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/frontend/lib/api.ts" \
  "$SERVER:$SERVER_PATH/frontend/lib/" 2>&1 | grep -v "Warning"

# Backend файлы
echo "📦 Синхронизация backend..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/backend/utils/pdf_generator.py" \
  "$SERVER:$SERVER_PATH/backend/utils/pdf_generator.py" 2>&1 | grep -v "Warning"

echo "✅ Синхронизация завершена"
echo ""
echo "🔄 Перезапуск frontend контейнера..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" \
  "cd $SERVER_PATH && docker compose stop frontend && docker compose rm -f frontend && docker compose up -d --no-deps frontend" 2>&1 | grep -E "Stopping|Removed|Created|Started"

echo ""
echo "⏳ Ожидание запуска контейнера (45 секунд)..."
sleep 45

echo ""
echo "✅ Готово! Проверьте статус:"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" \
  "docker ps --filter name=frontend --format '{{.Names}} {{.Status}}'"

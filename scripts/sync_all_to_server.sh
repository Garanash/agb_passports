#!/bin/bash

# Полная синхронизация всех файлов на сервер

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

echo "🔄 Полная синхронизация файлов на сервер..."

# Frontend компоненты
echo "📦 Frontend компоненты..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/frontend/components/MainApp.tsx" \
  "$SERVER:$SERVER_PATH/frontend/components/" 2>&1 | grep -v "Warning" || true

# Frontend lib
echo "📦 Frontend lib..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/frontend/lib/api.ts" \
  "$SERVER:$SERVER_PATH/frontend/lib/" 2>&1 | grep -v "Warning" || true

# Frontend hooks
echo "📦 Frontend hooks..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/frontend/hooks/usePassports.ts" \
  "$SERVER:$SERVER_PATH/frontend/hooks/" 2>&1 | grep -v "Warning" || true

# Backend endpoints
echo "📦 Backend endpoints..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/backend/api/v1/endpoints/nomenclature.py" \
  "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/" 2>&1 | grep -v "Warning" || true

sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/backend/api/v1/endpoints/passports.py" \
  "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/" 2>&1 | grep -v "Warning" || true

# Backend database
echo "📦 Backend database..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/backend/database.py" \
  "$SERVER:$SERVER_PATH/backend/" 2>&1 | grep -v "Warning" || true

# Backend utils
echo "📦 Backend utils..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
  "$LOCAL_PATH/backend/utils/pdf_generator.py" \
  "$SERVER:$SERVER_PATH/backend/utils/" 2>&1 | grep -v "Warning" || true

echo "✅ Все файлы синхронизированы"

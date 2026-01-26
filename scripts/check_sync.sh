#!/bin/bash
# Скрипт для проверки синхронизации файлов

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

echo "🔍 Проверка синхронизации файлов..."
echo ""

# Получаем MD5 локальных файлов
echo "Локальные файлы:"
md5 "$LOCAL_PATH/frontend/pages/login.tsx" "$LOCAL_PATH/frontend/components/MainApp.tsx" "$LOCAL_PATH/frontend/hooks/usePassports.ts" "$LOCAL_PATH/frontend/lib/api.ts" 2>&1 | grep -E 'MD5|login|MainApp|usePassports|api'

echo ""
echo "Файлы на сервере:"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" \
  "md5sum $SERVER_PATH/frontend/pages/login.tsx $SERVER_PATH/frontend/components/MainApp.tsx $SERVER_PATH/frontend/hooks/usePassports.ts $SERVER_PATH/frontend/lib/api.ts 2>&1"

echo ""
echo "✅ Если MD5 суммы совпадают, файлы идентичны"

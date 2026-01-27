#!/bin/bash

# Полная синхронизация всех файлов с сервером
# Синхронизирует абсолютно все как развернуто локально

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Полная синхронизация всех файлов с сервером${NC}"
echo ""

# Проверяем наличие sshpass
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}❌ sshpass не установлен. Установите: brew install hudochenkov/sshpass/sshpass${NC}"
    exit 1
fi

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

# Функция для копирования директории
scp_copy_dir() {
    local src=$1
    local dst=$2
    ssh_exec "mkdir -p $dst" 2>&1 | grep -v "Warning" || true
    sshpass -p "$PASSWORD" scp -r -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$src" "$SERVER:$dst" 2>&1 | grep -v "Warning" || true
}

echo -e "${YELLOW}📦 Шаг 1: Создание всех необходимых директорий на сервере...${NC}"
ssh_exec "mkdir -p $SERVER_PATH/backend/api/v1/endpoints" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/backend/utils/templates" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/backend/utils/templates/backups" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/components" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/lib" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/backups" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/scripts" 2>&1 | grep -v "Warning" || true

echo -e "${YELLOW}📤 Шаг 2: Синхронизация backend файлов...${NC}"
scp_copy "$LOCAL_PATH/backend/utils/sticker_template_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"
scp_copy "$LOCAL_PATH/backend/utils/template_manager.py" "$SERVER:$SERVER_PATH/backend/utils/"
scp_copy "$LOCAL_PATH/backend/utils/barcode_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"
scp_copy "$LOCAL_PATH/backend/api/v1/endpoints/templates.py" "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/"
scp_copy_dir "$LOCAL_PATH/backend/utils/templates" "$SERVER_PATH/backend/utils/"

echo -e "${YELLOW}📤 Шаг 3: Синхронизация frontend файлов...${NC}"
scp_copy "$LOCAL_PATH/frontend/components/StickerTemplateEditor.tsx" "$SERVER:$SERVER_PATH/frontend/components/"
scp_copy "$LOCAL_PATH/frontend/lib/api.ts" "$SERVER:$SERVER_PATH/frontend/lib/"

echo -e "${YELLOW}📤 Шаг 4: Синхронизация конфигурационных файлов...${NC}"
scp_copy "$LOCAL_PATH/docker-compose.yml" "$SERVER:$SERVER_PATH/"
scp_copy "$LOCAL_PATH/Dockerfile.backend" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/Dockerfile.frontend" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/nginx.conf" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true

echo -e "${YELLOW}📤 Шаг 5: Синхронизация скриптов...${NC}"
scp_copy_dir "$LOCAL_PATH/scripts" "$SERVER_PATH/"

echo -e "${YELLOW}🔄 Шаг 6: Перезапуск контейнеров на сервере...${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose restart backend frontend" 2>&1 | grep -v "Warning" || true

echo -e "${YELLOW}⏳ Ожидание запуска сервисов...${NC}"
sleep 10

echo -e "${GREEN}✅ Полная синхронизация завершена!${NC}"
echo ""
echo -e "${BLUE}📊 Проверка статуса:${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose ps" 2>&1 | grep -v "Warning" || true

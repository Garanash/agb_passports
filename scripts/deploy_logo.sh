#!/bin/bash

# Скрипт для деплоя логотипа и обновленных файлов

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📤 Деплой логотипа и обновленных файлов${NC}"
echo ""

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📤 Копирование обновленных файлов...${NC}"
scp_copy "$LOCAL_PATH/backend/utils/pdf_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"
scp_copy "$LOCAL_PATH/backend/utils/sticker_template_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"

echo ""
echo -e "${YELLOW}📤 Копирование логотипа...${NC}"
ssh_exec "mkdir -p $SERVER_PATH/backend/utils/templates 2>&1" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/utils/templates/logo.png" "$SERVER:$SERVER_PATH/backend/utils/templates/"

echo ""
echo -e "${YELLOW}🔍 Проверка логотипа на сервере...${NC}"
ssh_exec "ls -lh $SERVER_PATH/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "Логотип не найден"

echo ""
echo -e "${YELLOW}📋 Копирование логотипа в контейнер...${NC}"
ssh_exec "docker cp $SERVER_PATH/backend/utils/templates/logo.png agb_backend:/app/backend/utils/templates/logo.png 2>&1 || docker exec agb_backend mkdir -p /app/backend/utils/templates && docker cp $SERVER_PATH/backend/utils/templates/logo.png agb_backend:/app/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (5 секунд)...${NC}"
sleep 5

echo ""
echo -e "${YELLOW}🔍 Проверка логотипа в контейнере...${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "Логотип не найден в контейнере"

echo ""
echo -e "${GREEN}✅ Деплой завершен!${NC}"
echo ""
echo -e "${YELLOW}📝 Примечание:${NC}"
echo "   Логотип должен быть доступен по пути:"
echo "   /app/backend/utils/templates/logo.png (в контейнере)"
echo "   $SERVER_PATH/backend/utils/templates/logo.png (на сервере)"
echo ""

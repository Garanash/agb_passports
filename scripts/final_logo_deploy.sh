#!/bin/bash

# Финальный скрипт для деплоя логотипа

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📤 Финальный деплой логотипа${NC}"
echo ""

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📤 Синхронизация файлов...${NC}"
scp_copy "$LOCAL_PATH/backend/utils/pdf_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"
scp_copy "$LOCAL_PATH/backend/utils/sticker_template_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"
scp_copy "$LOCAL_PATH/docker-compose.yml" "$SERVER:$SERVER_PATH/"

echo ""
echo -e "${YELLOW}📤 Копирование логотипа...${NC}"
ssh_exec "mkdir -p $SERVER_PATH/backend/utils/templates 2>&1" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/utils/templates/logo.png" "$SERVER:$SERVER_PATH/backend/utils/templates/"

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend с обновленным docker-compose...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose down backend 2>&1 && docker compose up -d backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (8 секунд)...${NC}"
sleep 8

echo ""
echo -e "${YELLOW}🔍 Финальная проверка...${NC}"
echo "Логотип на сервере:"
ssh_exec "ls -lh $SERVER_PATH/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "Не найден"

echo ""
echo "Логотип в контейнере:"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "Не найден"

echo ""
echo -e "${GREEN}✅ Деплой завершен!${NC}"
echo ""
echo -e "${YELLOW}📝 Теперь логотип будет использоваться в:${NC}"
echo "   ✅ Паспортах (PDF)"
echo "   ✅ Наклейках (PDF)"
echo "   ✅ Наклейках (DOCX)"
echo ""

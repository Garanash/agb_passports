#!/bin/bash

# Скрипт для обновления sticker_template_generator.py

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📤 Обновление sticker_template_generator.py${NC}"
echo ""

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📤 Копирование файла на сервер...${NC}"
scp_copy "$LOCAL_PATH/backend/utils/sticker_template_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"

echo ""
echo -e "${YELLOW}📋 Копирование файла в контейнер...${NC}"
ssh_exec "docker cp $SERVER_PATH/backend/utils/sticker_template_generator.py agb_backend:/app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (5 секунд)...${NC}"
sleep 5

echo ""
echo -e "${GREEN}✅ Обновление завершено!${NC}"
echo ""
echo -e "${YELLOW}📝 Логотип теперь используется в:${NC}"
echo "   ✅ Паспортах (PDF)"
echo "   ✅ Наклейках (PDF)"
echo "   ✅ Наклейках (DOCX)"
echo ""

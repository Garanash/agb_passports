#!/bin/bash

# Скрипт для синхронизации исправлений логотипа

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📤 Синхронизация исправлений логотипа${NC}"
echo ""

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📤 Копирование исправленных файлов...${NC}"
scp_copy "$LOCAL_PATH/backend/utils/pdf_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"
scp_copy "$LOCAL_PATH/backend/utils/sticker_template_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"
echo -e "${GREEN}✅ Файлы скопированы${NC}"

echo ""
echo -e "${YELLOW}🔍 Проверка наличия логотипа на сервере...${NC}"
ssh_exec "ls -lh $SERVER_PATH/backend/utils/templates/logo.png 2>/dev/null || echo 'Логотип не найден'" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (5 секунд)...${NC}"
sleep 5

echo ""
echo -e "${GREEN}✅ Синхронизация завершена!${NC}"
echo ""
echo -e "${YELLOW}📝 Примечание:${NC}"
echo "   Убедитесь, что файл logo.png находится в:"
echo "   $SERVER_PATH/backend/utils/templates/logo.png"
echo ""

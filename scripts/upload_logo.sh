#!/bin/bash

# Скрипт для загрузки логотипа на сервер

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}📤 Загрузка логотипа на сервер${NC}"
echo ""

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

LOGO_LOCAL="$LOCAL_PATH/backend/utils/templates/logo.png"

echo -e "${YELLOW}🔍 Проверка логотипа локально...${NC}"
if [ -f "$LOGO_LOCAL" ]; then
    echo -e "${GREEN}✅ Логотип найден локально: $LOGO_LOCAL${NC}"
    FILE_SIZE=$(ls -lh "$LOGO_LOCAL" | awk '{print $5}')
    echo "   Размер: $FILE_SIZE"
else
    echo -e "${RED}❌ Логотип не найден локально: $LOGO_LOCAL${NC}"
    echo -e "${YELLOW}⚠️  Продолжаем без локального файла...${NC}"
fi

echo ""
echo -e "${YELLOW}📤 Создание директории на сервере...${NC}"
ssh_exec "mkdir -p $SERVER_PATH/backend/utils/templates 2>&1" 2>&1 | grep -v "Warning" || true

if [ -f "$LOGO_LOCAL" ]; then
    echo ""
    echo -e "${YELLOW}📤 Копирование логотипа на сервер...${NC}"
    scp_copy "$LOGO_LOCAL" "$SERVER:$SERVER_PATH/backend/utils/templates/"
    echo -e "${GREEN}✅ Логотип скопирован${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠️  Локальный файл не найден, проверяем наличие на сервере...${NC}"
fi

echo ""
echo -e "${YELLOW}🔍 Проверка логотипа на сервере...${NC}"
ssh_exec "ls -lh $SERVER_PATH/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "Логотип не найден на сервере"

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${GREEN}✅ Готово!${NC}"
echo ""

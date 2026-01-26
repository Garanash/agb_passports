#!/bin/bash

# Скрипт для запуска nginx

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Запуск nginx${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🚀 Запуск nginx...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose up -d nginx 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска nginx (5 секунд)...${NC}"
sleep 5

echo ""
echo -e "${YELLOW}📊 Статус всех контейнеров:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" || true

echo ""
echo -e "${YELLOW}🔍 Проверка nginx...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs nginx --tail 10 2>&1" 2>&1 | tail -15

echo ""
echo -e "${GREEN}✅ Готово!${NC}"
echo ""

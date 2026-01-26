#!/bin/bash

# Скрипт для проверки работы API на фронтенде

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка работы API на фронтенде${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📋 Логи frontend (последние 30 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs frontend --tail 30 2>&1" 2>&1 | tail -40

echo ""
echo -e "${YELLOW}📋 Логи nginx (последние 20 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs nginx --tail 20 2>&1" 2>&1 | tail -25

echo ""
echo -e "${YELLOW}🧪 Тест доступности API через nginx...${NC}"
API_TEST=$(ssh_exec "curl -s http://localhost/api/v1/passports/health 2>&1" 2>&1 | head -5)
echo "$API_TEST"

echo ""
echo -e "${YELLOW}🧪 Тест доступности frontend...${NC}"
FRONTEND_TEST=$(ssh_exec "curl -s -I http://localhost 2>&1 | head -5" 2>&1)
echo "$FRONTEND_TEST"

echo ""
echo -e "${YELLOW}🔍 Проверка файла lib/api.ts на сервере...${NC}"
ssh_exec "ls -lh $SERVER_PATH/frontend/lib/api.ts 2>&1" 2>&1 | grep -v "Warning" || echo "Файл не найден"

echo ""
echo -e "${YELLOW}🔍 Проверка содержимого lib/api.ts (первые 20 строк)...${NC}"
ssh_exec "head -20 $SERVER_PATH/frontend/lib/api.ts 2>&1" 2>&1 | grep -v "Warning" || echo "Не удалось прочитать файл"

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

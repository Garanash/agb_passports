#!/bin/bash

# Скрипт для перезапуска nginx

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔄 Перезапуск nginx${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔄 Перезапуск nginx...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart nginx 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска nginx (3 секунды)...${NC}"
sleep 3

echo ""
echo -e "${YELLOW}📊 Статус nginx...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps nginx 2>&1" 2>&1 | grep -E "NAME|agb_nginx" || true

echo ""
echo -e "${YELLOW}🧪 Тест подключения к API через nginx...${NC}"
API_TEST=$(ssh_exec "curl -s http://localhost/api/v1/passports/health 2>&1" 2>&1)
if echo "$API_TEST" | grep -q "healthy"; then
    echo -e "${GREEN}✅ API доступен через nginx!${NC}"
    echo "   $API_TEST"
else
    echo -e "${RED}❌ API недоступен${NC}"
    echo "   $API_TEST"
fi

echo ""
echo -e "${YELLOW}🧪 Тест получения паспортов через nginx (без авторизации для проверки)...${NC}"
PASSPORTS_TEST=$(ssh_exec "curl -s 'http://localhost/api/v1/passports/?page=1&page_size=1' 2>&1" 2>&1 | head -3)
echo "$PASSPORTS_TEST"

echo ""
echo -e "${GREEN}✅ Перезапуск завершен!${NC}"
echo ""

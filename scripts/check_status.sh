#!/bin/bash

# Скрипт для проверки статуса приложения на сервере

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка статуса приложения${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📊 Статус контейнеров:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" || true

echo ""
echo -e "${YELLOW}🔍 Проверка доступности сервисов:${NC}"

# Проверка backend
echo -n "Backend API (8000): "
if ssh_exec "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/health 2>/dev/null || echo '000'" 2>&1 | grep -q "200"; then
    echo -e "${GREEN}✅ Работает${NC}"
else
    echo -e "${RED}❌ Недоступен${NC}"
fi

# Проверка frontend
echo -n "Frontend (3000): "
if ssh_exec "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000 2>/dev/null || echo '000'" 2>&1 | grep -qE "200|301|302"; then
    echo -e "${GREEN}✅ Работает${NC}"
else
    echo -e "${RED}❌ Недоступен${NC}"
fi

# Проверка nginx
echo -n "Nginx (80): "
if ssh_exec "curl -s -o /dev/null -w '%{http_code}' http://localhost 2>/dev/null || echo '000'" 2>&1 | grep -qE "200|301|302"; then
    echo -e "${GREEN}✅ Работает${NC}"
else
    echo -e "${RED}❌ Недоступен${NC}"
fi

echo ""
echo -e "${YELLOW}📋 Последние логи frontend:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs frontend --tail 10 2>&1" 2>&1 | tail -15

echo ""
echo -e "${YELLOW}📋 Последние логи nginx:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs nginx --tail 5 2>&1" 2>&1 | tail -10

echo ""
echo -e "${BLUE}🌐 Приложение доступно по адресам:${NC}"
echo "   http://185.247.17.188"
echo "   http://185.247.17.188:8000/docs (API Docs)"
echo ""

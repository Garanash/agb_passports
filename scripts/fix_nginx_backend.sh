#!/bin/bash

# Скрипт для исправления подключения nginx к backend

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление подключения nginx к backend${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔍 Проверка IP адреса backend контейнера:${NC}"
BACKEND_IP=$(ssh_exec "docker inspect agb_backend --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>&1" 2>&1 | grep -v "Warning")
echo "   IP адрес backend: $BACKEND_IP"

echo ""
echo -e "${YELLOW}🧪 Тест подключения к backend из nginx:${NC}"
CONNECTION_TEST=$(ssh_exec "docker exec agb_nginx wget -q -O- --timeout=2 http://backend:8000/health 2>&1" 2>&1 | grep -v "Warning")
if echo "$CONNECTION_TEST" | grep -q "healthy"; then
    echo -e "${GREEN}✅ Nginx может подключиться к backend${NC}"
else
    echo -e "${YELLOW}⚠️ Проблема с подключением: $CONNECTION_TEST${NC}"
fi

echo ""
echo -e "${YELLOW}🔄 Перезапуск nginx для обновления upstream:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart nginx 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска nginx (3 секунды)...${NC}"
sleep 3

echo ""
echo -e "${YELLOW}🧪 Тест API через nginx после перезапуска:${NC}"
HEALTH_TEST=$(ssh_exec "curl -s http://localhost/api/v1/passports/health 2>&1" 2>&1)
if echo "$HEALTH_TEST" | grep -q "healthy"; then
    echo -e "${GREEN}✅ API работает через nginx${NC}"
    echo "   $HEALTH_TEST"
else
    echo -e "${RED}❌ API не работает через nginx${NC}"
    echo "   $HEALTH_TEST"
fi

echo ""
echo -e "${YELLOW}📊 Статус nginx:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps nginx 2>&1" 2>&1 | grep -E "NAME|agb_nginx" || true

echo ""
echo -e "${GREEN}✅ Исправление завершено!${NC}"
echo ""

#!/bin/bash

# Скрипт для исправления пароля и тестирования входа

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление пароля и тестирование входа${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔑 Установка пароля PostgreSQL...${NC}"
ssh_exec "docker exec agb_postgres psql -U postgres -c \"ALTER ROLE postgres WITH PASSWORD 'password';\" 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (8 секунд)...${NC}"
sleep 8

echo ""
echo -e "${YELLOW}🔍 Проверка статуса backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 5 2>&1" 2>&1 | tail -10

echo ""
echo -e "${YELLOW}🧪 Тест health endpoint...${NC}"
HEALTH=$(ssh_exec "curl -s http://localhost:8000/health 2>&1" 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    echo -e "${GREEN}✅ Backend работает!${NC}"
else
    echo -e "${RED}❌ Backend не работает${NC}"
    echo "   Ответ: $HEALTH"
fi

echo ""
echo -e "${YELLOW}🧪 Тест входа...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход успешен!${NC}"
    echo ""
    echo "Ответ сервера:"
    echo "$LOGIN_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$LOGIN_RESPONSE"
else
    echo -e "${RED}❌ Вход не работает${NC}"
    echo "   Ответ: $LOGIN_RESPONSE"
    echo ""
    echo -e "${YELLOW}📋 Последние логи backend:${NC}"
    ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 20 2>&1" 2>&1 | tail -25
fi

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

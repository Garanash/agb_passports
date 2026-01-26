#!/bin/bash

# Скрипт для исправления проблемы с подключением к БД

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление проблемы с подключением к БД${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔑 Установка правильного пароля PostgreSQL...${NC}"
ssh_exec "docker exec agb_postgres psql -U postgres -c \"ALTER ROLE postgres WITH PASSWORD 'password';\" 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔄 Остановка backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose stop backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔄 Удаление старого контейнера backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose rm -f backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🚀 Запуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose up -d backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (10 секунд)...${NC}"
sleep 10

echo ""
echo -e "${YELLOW}📋 Статус backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps backend 2>&1" 2>&1 | grep -E "NAME|agb_backend" || true

echo ""
echo -e "${YELLOW}📋 Последние логи backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 20 2>&1" 2>&1 | tail -25

echo ""
echo -e "${YELLOW}🧪 Тест health endpoint...${NC}"
HEALTH=$(ssh_exec "curl -s http://localhost:8000/health 2>&1" 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    echo -e "${GREEN}✅ Backend работает!${NC}"
    echo "   Ответ: $HEALTH"
else
    echo -e "${RED}❌ Backend не работает${NC}"
    echo "   Ответ: $HEALTH"
fi

echo ""
echo -e "${YELLOW}🧪 Тест получения паспортов (без авторизации для проверки)...${NC}"
PASSPORTS_RESPONSE=$(ssh_exec "curl -s http://localhost:8000/api/v1/passports/ 2>&1" 2>&1 | head -5)
echo "$PASSPORTS_RESPONSE"

echo ""
echo -e "${GREEN}✅ Исправление завершено!${NC}"
echo ""

#!/bin/bash

# Скрипт для проверки ошибки входа

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка ошибки входа${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🧪 Тест входа...${NC}"
ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1

echo ""
echo ""
echo -e "${YELLOW}📋 Последние логи backend после запроса входа:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 30 2>&1" 2>&1 | tail -40

echo ""
echo -e "${YELLOW}🔍 Проверка пароля в базе данных:${NC}"
ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c \"SELECT username, LEFT(hashed_password, 50) as password_hash FROM users WHERE username='admin';\" 2>/dev/null" 2>&1 | grep -v "Warning" | head -5

echo ""

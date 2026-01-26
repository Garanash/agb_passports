#!/bin/bash

# Скрипт для исправления пароля БД

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление пароля БД${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔑 Исправление пароля БД...${NC}"
ssh_exec "docker exec -i agb_postgres psql -U postgres <<EOF
ALTER ROLE postgres WITH PASSWORD 'password';
SELECT 'Password updated successfully' as status;
\q
EOF
" > /dev/null 2>&1

echo -e "${GREEN}✅ Пароль обновлен${NC}"

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (8 секунд)...${NC}"
sleep 8

echo ""
echo -e "${YELLOW}🧪 Проверка логина...${NC}"
LOGIN_TEST=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' | python3 -c 'import sys, json; data = json.load(sys.stdin); print(\"OK\" if \"access_token\" in data else \"FAIL\")' 2>&1" 2>&1 | grep -v "Warning" | tail -1)

if [ "$LOGIN_TEST" = "OK" ]; then
    echo -e "${GREEN}✅ Логин работает!${NC}"
else
    echo -e "${YELLOW}⚠️ Логин не работает, проверьте логи${NC}"
fi

echo ""
echo -e "${GREEN}✅ Исправление завершено!${NC}"
echo ""

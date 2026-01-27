#!/bin/bash

# Скрипт для исправления входа администратора

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление входа администратора${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

# Вычисляем правильный хеш
ADMIN_HASH=$(python3 -c "import hashlib; print('sha256\$' + hashlib.sha256(b'admin').hexdigest())")
echo -e "${YELLOW}🔑 Хеш пароля 'admin': $ADMIN_HASH${NC}"

echo ""
echo -e "${YELLOW}📝 Обновление пароля в базе данных...${NC}"
ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c \"UPDATE users SET hashed_password='$ADMIN_HASH', is_active=true WHERE username='admin';\" 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔍 Проверка пользователя...${NC}"
ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c \"SELECT username, role, is_active, LEFT(hashed_password, 20) as hash_preview FROM users WHERE username='admin';\" 2>&1" 2>&1 | grep -v "Warning" | grep -E "(admin|username)" || true

echo ""
echo -e "${YELLOW}🧪 Тест входа...${NC}"
sleep 2
RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1 | grep -v "Warning")

if echo "$RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход успешен!${NC}"
    echo ""
    echo "Токен получен. Теперь можно войти в приложение с:"
    echo "   Username: admin"
    echo "   Password: admin"
else
    echo -e "${RED}❌ Вход не работает${NC}"
    echo "Ответ сервера: $RESPONSE"
    echo ""
    echo -e "${YELLOW}🔍 Проверка хеша в базе...${NC}"
    DB_HASH=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c \"SELECT hashed_password FROM users WHERE username='admin';\" 2>&1" 2>&1 | grep -v "Warning" | tr -d ' ')
    echo "Ожидаемый: $ADMIN_HASH"
    echo "В базе:    $DB_HASH"
fi

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"

#!/bin/bash

# Скрипт для исправления пароля администратора

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление пароля администратора${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔍 Проверка текущего хеша пароля...${NC}"
CURRENT_HASH=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c \"SELECT hashed_password FROM users WHERE username='admin';\" 2>/dev/null" 2>&1 | grep -v "Warning" | tr -d ' ')
echo "Текущий хеш: ${CURRENT_HASH:0:60}..."

echo ""
echo -e "${YELLOW}🔑 Вычисление правильного хеша для пароля 'admin'...${NC}"
CORRECT_HASH=$(ssh_exec "python3 -c \"import hashlib; print('sha256\$' + hashlib.sha256(b'admin').hexdigest())\" 2>/dev/null" 2>&1 | grep -v "Warning" | tail -1)
echo "Правильный хеш: $CORRECT_HASH"

echo ""
echo -e "${YELLOW}🔧 Обновление пароля в базе данных...${NC}"
ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c \"UPDATE users SET hashed_password='$CORRECT_HASH' WHERE username='admin';\" 2>/dev/null" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔍 Проверка обновленного хеша...${NC}"
NEW_HASH=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c \"SELECT hashed_password FROM users WHERE username='admin';\" 2>/dev/null" 2>&1 | grep -v "Warning" | tr -d ' ')
echo "Новый хеш: ${NEW_HASH:0:60}..."

echo ""
echo -e "${YELLOW}🧪 Тест входа...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход успешен!${NC}"
    echo ""
    echo "Ответ сервера:"
    echo "$LOGIN_RESPONSE" | python3 -m json.tool 2>/dev/null | head -15 || echo "$LOGIN_RESPONSE" | head -5
    echo ""
    echo -e "${GREEN}🎉 Проблема решена! Теперь можно войти в приложение.${NC}"
else
    echo -e "${RED}❌ Вход все еще не работает${NC}"
    echo "   Ответ: $LOGIN_RESPONSE"
    echo ""
    echo -e "${YELLOW}🔍 Проверка хешей...${NC}"
    echo "   Ожидаемый: $CORRECT_HASH"
    echo "   В базе:    $NEW_HASH"
fi

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

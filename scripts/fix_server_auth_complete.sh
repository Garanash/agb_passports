#!/bin/bash

# Полное исправление аутентификации на сервере

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Полное исправление аутентификации на сервере${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

echo -e "${YELLOW}📤 Шаг 1: Синхронизация auth.py...${NC}"
scp_copy "$LOCAL_PATH/backend/api/auth.py" "$SERVER:$SERVER_PATH/backend/api/"

echo -e "${YELLOW}🔑 Шаг 2: Исправление пароля admin в базе данных...${NC}"
ADMIN_HASH=$(python3 -c "import hashlib; print('sha256\$' + hashlib.sha256(b'admin').hexdigest())")
echo "Хеш: $ADMIN_HASH"

# Проверяем, существует ли пользователь
USER_EXISTS=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c \"SELECT COUNT(*) FROM users WHERE username='admin';\" 2>/dev/null" 2>&1 | grep -v "Warning" | tr -d ' ' || echo "0")

if [ "$USER_EXISTS" = "1" ]; then
    echo "Пользователь существует, обновляем пароль..."
    ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c \"UPDATE users SET hashed_password='$ADMIN_HASH', is_active=true WHERE username='admin';\" 2>&1" 2>&1 | grep -v "Warning" || true
else
    echo "Пользователь не существует, создаем..."
    ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c \"INSERT INTO users (username, email, full_name, hashed_password, role, is_active) VALUES ('admin', 'admin@agb-passports.ru', 'Супер Администратор', '$ADMIN_HASH', 'admin', true) ON CONFLICT (username) DO UPDATE SET hashed_password='$ADMIN_HASH', is_active=true;\" 2>&1" 2>&1 | grep -v "Warning" || true
fi

echo ""
echo -e "${YELLOW}🔄 Шаг 3: Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend...${NC}"
sleep 10

echo ""
echo -e "${YELLOW}🧪 Шаг 4: Тест входа...${NC}"
RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1 | grep -v "Warning")

if echo "$RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход успешен!${NC}"
    echo ""
    echo "Токен получен. Данные для входа:"
    echo "   Username: admin"
    echo "   Password: admin"
else
    echo -e "${RED}❌ Вход не работает${NC}"
    echo "Ответ: $RESPONSE"
    echo ""
    echo -e "${YELLOW}🔍 Проверка хеша в базе...${NC}"
    DB_HASH=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c \"SELECT hashed_password FROM users WHERE username='admin';\" 2>&1" 2>&1 | grep -v "Warning" | tr -d ' ')
    echo "Ожидаемый: $ADMIN_HASH"
    echo "В базе:    $DB_HASH"
    echo ""
    echo -e "${YELLOW}📋 Последние ошибки backend...${NC}"
    ssh_exec "cd $SERVER_PATH && docker compose logs --tail=10 backend 2>&1 | grep -i error" 2>&1 | grep -v "Warning" | tail -5 || echo "Ошибок не найдено"
fi

echo ""
echo -e "${GREEN}✅ Исправление завершено!${NC}"

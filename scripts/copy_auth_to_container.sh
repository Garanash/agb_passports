#!/bin/bash

# Скрипт для копирования auth.py напрямую в контейнер

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📤 Копирование auth.py напрямую в контейнер${NC}"
echo ""

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📤 Копирование файла на сервер...${NC}"
scp_copy "$LOCAL_PATH/backend/api/auth.py" "$SERVER:/tmp/auth.py"

echo ""
echo -e "${YELLOW}📋 Копирование файла в контейнер...${NC}"
ssh_exec "docker cp /tmp/auth.py agb_backend:/app/backend/api/auth.py 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔍 Проверка содержимого файла в контейнере...${NC}"
ssh_exec "docker exec agb_backend grep -A 10 'def verify_password' /app/backend/api/auth.py 2>&1" 2>&1 | head -15

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (8 секунд)...${NC}"
sleep 8

echo ""
echo -e "${YELLOW}🧪 Тест входа...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход успешен!${NC}"
    echo ""
    echo "Ответ сервера:"
    echo "$LOGIN_RESPONSE" | python3 -m json.tool 2>/dev/null | head -10 || echo "$LOGIN_RESPONSE" | head -5
else
    echo -e "${RED}❌ Вход не работает${NC}"
    echo "   Ответ: $LOGIN_RESPONSE"
fi

echo ""
echo -e "${GREEN}✅ Готово!${NC}"
echo ""

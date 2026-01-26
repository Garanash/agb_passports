#!/bin/bash

# Скрипт для пересборки backend с исправленным auth.py

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Пересборка backend с исправлениями${NC}"
echo ""

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📤 Копирование исправленного auth.py...${NC}"
scp_copy "$LOCAL_PATH/backend/api/auth.py" "$SERVER:$SERVER_PATH/backend/api/"
echo -e "${GREEN}✅ Файл скопирован${NC}"

echo ""
echo -e "${YELLOW}🔍 Проверка содержимого файла на сервере...${NC}"
ssh_exec "grep -A 5 'def verify_password' $SERVER_PATH/backend/api/auth.py 2>&1" 2>&1 | head -10

echo ""
echo -e "${YELLOW}🛑 Остановка backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose stop backend 2>&1" 2>&1 | grep -v "Warning" || true
ssh_exec "cd $SERVER_PATH && docker compose rm -f backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🏗️  Пересборка backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose build --no-cache backend 2>&1" 2>&1 | tail -20

echo ""
echo -e "${YELLOW}🚀 Запуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose up -d backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (10 секунд)...${NC}"
sleep 10

echo ""
echo -e "${YELLOW}🧪 Тест входа...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход успешен!${NC}"
    echo "   Токен получен"
else
    echo -e "${RED}❌ Вход не работает${NC}"
    echo "   Ответ: $LOGIN_RESPONSE"
    echo ""
    echo -e "${YELLOW}📋 Последние логи backend:${NC}"
    ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 15 2>&1" 2>&1 | tail -20
fi

echo ""
echo -e "${GREEN}✅ Готово!${NC}"
echo ""

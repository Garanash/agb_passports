#!/bin/bash

# Исправление всех трех проблем

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление всех трех проблем${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📋 Проблемы:${NC}"
echo "1. Ошибка при экспорте наклеек"
echo "2. Ошибка при экспорте паспортов в Excel"
echo "3. Ошибка загрузки шаблонов: Could not validate credentials"
echo ""

echo -e "${YELLOW}📦 Копирование исправленных файлов...${NC}"

# Копируем файлы
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no backend/api/v1/endpoints/passports.py "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/passports.py" 2>&1 | grep -v "Warning" || true
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no backend/api/v1/endpoints/templates.py "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/templates.py" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Файлы скопированы${NC}"

echo ""
echo -e "${YELLOW}📦 Копирование файлов в контейнер...${NC}"
ssh_exec "docker cp $SERVER_PATH/backend/api/v1/endpoints/passports.py agb_backend:/app/backend/api/v1/endpoints/passports.py 2>&1" 2>&1 | grep -v "Warning" || true
ssh_exec "docker cp $SERVER_PATH/backend/api/v1/endpoints/templates.py agb_backend:/app/backend/api/v1/endpoints/templates.py 2>&1" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Файлы скопированы в контейнер${NC}"

echo ""
echo -e "${YELLOW}🔑 Исправление пароля БД...${NC}"
ssh_exec "docker exec -i agb_postgres psql -U postgres <<EOF
ALTER ROLE postgres WITH PASSWORD 'password';
\q
EOF
" > /dev/null 2>&1

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (8 секунд)...${NC}"
sleep 8

echo ""
echo -e "${YELLOW}📋 Статус backend:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps backend 2>&1" 2>&1 | grep -E "NAME|agb_backend" || true

echo ""
echo -e "${GREEN}✅ Исправления применены!${NC}"
echo ""

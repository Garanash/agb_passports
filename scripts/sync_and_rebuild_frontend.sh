#!/bin/bash

# Скрипт для синхронизации и пересборки фронтенда

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔄 Синхронизация и пересборка фронтенда${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📦 Синхронизация файлов фронтенда...${NC}"

# Синхронизируем важные файлы
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no frontend/lib/api.ts "$SERVER:$SERVER_PATH/frontend/lib/api.ts" 2>&1 | grep -v "Warning" || true
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no frontend/hooks/usePassports.ts "$SERVER:$SERVER_PATH/frontend/hooks/usePassports.ts" 2>&1 | grep -v "Warning" || true
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no frontend/components/MainApp.tsx "$SERVER:$SERVER_PATH/frontend/components/MainApp.tsx" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Файлы синхронизированы${NC}"

echo ""
echo -e "${YELLOW}🔄 Пересборка фронтенда...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose stop frontend 2>&1" 2>&1 | grep -v "Warning" || true
ssh_exec "cd $SERVER_PATH && docker compose rm -f frontend 2>&1" 2>&1 | grep -v "Warning" || true
ssh_exec "cd $SERVER_PATH && docker compose build frontend 2>&1" 2>&1 | tail -10
ssh_exec "cd $SERVER_PATH && docker compose up -d frontend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска фронтенда (15 секунд)...${NC}"
sleep 15

echo ""
echo -e "${YELLOW}📊 Статус фронтенда...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps frontend 2>&1" 2>&1 | grep -E "NAME|agb_frontend" || true

echo ""
echo -e "${YELLOW}📋 Логи фронтенда (последние 10 строк)...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs frontend --tail 10 2>&1" 2>&1 | tail -15

echo ""
echo -e "${YELLOW}🔄 Перезапуск nginx...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart nginx 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${GREEN}✅ Пересборка завершена!${NC}"
echo -e "${BLUE}💡 Обновите страницу в браузере (Ctrl+F5 или Cmd+Shift+R)${NC}"
echo ""

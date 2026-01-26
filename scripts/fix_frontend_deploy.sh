#!/bin/bash

# Быстрый скрипт для исправления frontend и пересборки

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление frontend и пересборка${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

echo -e "${YELLOW}📤 Синхронизация исправленного MainApp.tsx...${NC}"
scp_copy "$LOCAL_PATH/frontend/components/MainApp.tsx" "$SERVER:$SERVER_PATH/frontend/components/"
echo -e "${GREEN}✅ Файл синхронизирован${NC}"
echo ""

echo -e "${YELLOW}🛑 Остановка frontend контейнера...${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose stop frontend 2>/dev/null || docker compose stop frontend 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
ssh_exec "cd $SERVER_PATH && docker-compose rm -f frontend 2>/dev/null || docker compose rm -f frontend 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Frontend остановлен${NC}"
echo ""

echo -e "${YELLOW}🏗️  Пересборка frontend...${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose build --no-cache frontend 2>&1 || docker compose build --no-cache frontend 2>&1" 2>&1 | tail -30
echo ""

echo -e "${YELLOW}🚀 Запуск frontend...${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose up -d frontend 2>&1 || docker compose up -d frontend 2>&1" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Frontend запущен${NC}"
echo ""

echo -e "${YELLOW}⏳ Ожидание сборки frontend (60 секунд)...${NC}"
sleep 60

echo -e "${YELLOW}🚀 Запуск nginx...${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose up -d nginx 2>&1 || docker compose up -d nginx 2>&1" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Nginx запущен${NC}"
echo ""

echo -e "${YELLOW}🔍 Проверка статуса...${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose ps 2>&1 || docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" || true

echo ""
echo -e "${GREEN}✅ Готово!${NC}"
echo ""

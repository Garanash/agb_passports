#!/bin/bash

# Скрипт для пересборки frontend после исправлений

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Пересборка frontend с исправлениями${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

echo -e "${YELLOW}🧹 Очистка служебных файлов macOS...${NC}"
ssh_exec "cd $SERVER_PATH && find frontend -name '._*' -type f -delete 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
ssh_exec "cd $SERVER_PATH && find frontend -name '.DS_Store' -type f -delete 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Очистка завершена${NC}"
echo ""

echo -e "${YELLOW}📤 Синхронизация исправленных файлов...${NC}"
scp_copy "$LOCAL_PATH/frontend/components/MainApp.tsx" "$SERVER:$SERVER_PATH/frontend/components/"
scp_copy "$LOCAL_PATH/frontend/next.config.js" "$SERVER:$SERVER_PATH/frontend/"
scp_copy "$LOCAL_PATH/.dockerignore" "$SERVER:$SERVER_PATH/"
echo -e "${GREEN}✅ Файлы синхронизированы${NC}"
echo ""

echo -e "${YELLOW}🛑 Остановка frontend и nginx...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose stop frontend nginx 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
ssh_exec "cd $SERVER_PATH && docker compose rm -f frontend 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Контейнеры остановлены${NC}"
echo ""

echo -e "${YELLOW}🏗️  Пересборка frontend (это может занять несколько минут)...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose build --no-cache frontend 2>&1" 2>&1 | tail -40
echo ""

echo -e "${YELLOW}🚀 Запуск frontend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose up -d frontend 2>&1" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Frontend запущен${NC}"
echo ""

echo -e "${YELLOW}⏳ Ожидание сборки frontend (90 секунд)...${NC}"
sleep 90

echo -e "${YELLOW}🔍 Проверка статуса frontend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs frontend --tail 20 2>&1" 2>&1 | tail -25

echo ""
echo -e "${YELLOW}🚀 Запуск nginx...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose up -d nginx 2>&1" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Nginx запущен${NC}"
echo ""

echo -e "${YELLOW}🔍 Финальная проверка статуса...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" || true

echo ""
echo -e "${GREEN}✅ Пересборка завершена!${NC}"
echo ""

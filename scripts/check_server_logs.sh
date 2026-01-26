#!/bin/bash

# Скрипт для проверки логов на сервере

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка логов на сервере${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📋 Логи Backend (последние 50 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 50 2>&1" 2>&1 | tail -60

echo ""
echo -e "${YELLOW}📋 Логи Frontend (последние 30 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs frontend --tail 30 2>&1" 2>&1 | tail -40

echo ""
echo -e "${YELLOW}📋 Логи Nginx (последние 30 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs nginx --tail 30 2>&1" 2>&1 | tail -40

echo ""
echo -e "${YELLOW}📋 Проверка ошибок в логах Backend:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend 2>&1 | grep -i 'error\|exception\|traceback\|failed' | tail -20" 2>&1 | tail -25

echo ""
echo -e "${YELLOW}🔍 Проверка доступности API login endpoint:${NC}"
ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"test\",\"password\":\"test\"}' 2>&1" 2>&1 | head -10

echo ""
echo -e "${YELLOW}📊 Статус контейнеров:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" || true

echo ""

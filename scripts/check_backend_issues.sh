#!/bin/bash

# Скрипт для проверки проблем с backend

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка проблем с backend${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📊 Статус контейнеров:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" || true

echo ""
echo -e "${YELLOW}📋 Последние логи backend (50 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 50 2>&1" 2>&1 | tail -60

echo ""
echo -e "${YELLOW}🔍 Проверка ошибок в логах:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend 2>&1 | grep -i 'error\|exception\|traceback\|failed\|fatal' | tail -20" 2>&1 | tail -25

echo ""
echo -e "${YELLOW}🧪 Тест health endpoint:${NC}"
HEALTH=$(ssh_exec "curl -s http://localhost:8000/health 2>&1" 2>&1)
echo "$HEALTH"

echo ""
echo -e "${YELLOW}🧪 Тест получения паспортов:${NC}"
PASSPORTS=$(ssh_exec "curl -s -X GET http://localhost:8000/api/v1/passports/ -H 'Authorization: Bearer test' 2>&1" 2>&1 | head -10)
echo "$PASSPORTS"

echo ""
echo -e "${YELLOW}🔍 Проверка подключения к БД:${NC}"
DB_CHECK=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c 'SELECT COUNT(*) FROM ved_passports;' 2>&1" 2>&1 | grep -v "Warning" | head -5)
echo "$DB_CHECK"

echo ""
echo -e "${YELLOW}🔍 Проверка переменных окружения backend:${NC}"
ssh_exec "docker exec agb_backend env | grep -E 'DATABASE|SECRET' 2>&1" 2>&1 | grep -v "Warning" || true

echo ""

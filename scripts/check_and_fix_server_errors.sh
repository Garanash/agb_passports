#!/bin/bash

# Проверка и исправление всех ошибок на сервере

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка и исправление ошибок на сервере${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📦 Шаг 1: Проверка статуса контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps" 2>&1 | grep -v "Warning" || true
echo ""

echo -e "${YELLOW}📋 Шаг 2: Проверка последних ошибок backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs --tail=100 backend 2>&1 | grep -i 'error\|exception\|traceback\|failed' | tail -20" 2>&1 | grep -v "Warning" || echo "Ошибок не найдено"
echo ""

echo -e "${YELLOW}🗄️  Шаг 3: Проверка базы данных...${NC}"
DB_STATUS=$(ssh_exec "docker exec agb_postgres pg_isready -U postgres 2>&1" 2>&1 | grep -v "Warning" | tail -1)
if echo "$DB_STATUS" | grep -q "accepting connections"; then
    echo -e "${GREEN}✅ PostgreSQL готов${NC}"
else
    echo -e "${RED}❌ PostgreSQL недоступен${NC}"
fi
echo ""

echo -e "${YELLOW}🌐 Шаг 4: Проверка API...${NC}"
HEALTH=$(ssh_exec "curl -s http://localhost:8000/api/v1/health 2>&1" 2>&1 | grep -v "Warning" || echo "ERROR")
if echo "$HEALTH" | grep -q "ok\|healthy"; then
    echo -e "${GREEN}✅ Backend API работает${NC}"
else
    echo -e "${RED}❌ Backend API не отвечает${NC}"
    echo "Ответ: $HEALTH"
fi
echo ""

echo -e "${YELLOW}🔄 Шаг 5: Перезапуск всех сервисов...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart" 2>&1 | grep -v "Warning" || true
echo ""

echo -e "${YELLOW}⏳ Ожидание запуска сервисов...${NC}"
sleep 15

echo -e "${YELLOW}🧪 Шаг 6: Тест входа...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1 | grep -v "Warning")
if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход работает${NC}"
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    
    if [ ! -z "$TOKEN" ]; then
        echo -e "${YELLOW}🧪 Тест получения паспортов...${NC}"
        PASSPORTS_RESPONSE=$(ssh_exec "curl -s 'http://localhost:8000/api/v1/passports/?page=1&page_size=20' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1 | grep -v "Warning")
        if echo "$PASSPORTS_RESPONSE" | grep -q "passports\|total\|items"; then
            echo -e "${GREEN}✅ API паспортов работает${NC}"
        else
            echo -e "${RED}❌ Ошибка получения паспортов${NC}"
            echo "Ответ: ${PASSPORTS_RESPONSE:0:200}"
        fi
    fi
else
    echo -e "${RED}❌ Вход не работает${NC}"
    echo "Ответ: ${LOGIN_RESPONSE:0:200}"
fi
echo ""

echo -e "${YELLOW}📊 Шаг 7: Финальная проверка статуса...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps" 2>&1 | grep -v "Warning" | tail -6 || true
echo ""

echo -e "${GREEN}✅ Проверка завершена!${NC}"

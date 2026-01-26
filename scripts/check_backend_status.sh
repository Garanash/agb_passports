#!/bin/bash

# Скрипт для проверки состояния backend на сервере

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка состояния backend на сервере${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📊 Статус всех контейнеров:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" || true

echo ""
echo -e "${YELLOW}📋 Логи backend (последние 30 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 30 2>&1" 2>&1 | tail -35

echo ""
echo -e "${YELLOW}🔍 Проверка ошибок в логах:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend 2>&1 | grep -i 'error\|exception\|traceback\|failed\|fatal' | tail -10" 2>&1 | tail -15

echo ""
echo -e "${YELLOW}🧪 Тест health endpoint:${NC}"
HEALTH=$(ssh_exec "curl -s http://localhost:8000/health 2>&1" 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    echo -e "${GREEN}✅ Backend работает${NC}"
    echo "   $HEALTH"
else
    echo -e "${RED}❌ Backend не отвечает${NC}"
    echo "   $HEALTH"
fi

echo ""
echo -e "${YELLOW}🔐 Тест входа:${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход работает${NC}"
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    
    if [ ! -z "$TOKEN" ]; then
        echo ""
        echo -e "${YELLOW}📋 Тест получения паспортов:${NC}"
        PASSPORTS=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/?page=1&page_size=5' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$PASSPORTS" | grep -q "passports\|\["; then
            PASSPORT_COUNT=$(echo "$PASSPORTS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('passports', [])) if isinstance(data, dict) else len(data) if isinstance(data, list) else 0)" 2>/dev/null || echo "?")
            echo -e "${GREEN}✅ Паспорта загружаются (найдено: $PASSPORT_COUNT)${NC}"
        else
            echo -e "${RED}❌ Ошибка загрузки паспортов${NC}"
            echo "$PASSPORTS" | head -5
        fi
        
        echo ""
        echo -e "${YELLOW}📋 Тест получения номенклатуры:${NC}"
        NOMENCLATURE=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/nomenclature/' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$NOMENCLATURE" | grep -q "\["; then
            COUNT=$(echo "$NOMENCLATURE" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
            echo -e "${GREEN}✅ Номенклатура загружается (найдено: $COUNT)${NC}"
        else
            echo -e "${RED}❌ Ошибка загрузки номенклатуры${NC}"
            echo "$NOMENCLATURE" | head -5
        fi
    fi
else
    echo -e "${RED}❌ Вход не работает${NC}"
    echo "   Ответ: $LOGIN_RESPONSE" | head -3
fi

echo ""
echo -e "${YELLOW}🔍 Проверка подключения к БД:${NC}"
DB_CHECK=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c 'SELECT COUNT(*) FROM ved_passports;' 2>&1" 2>&1 | grep -v "Warning" | head -5)
echo "$DB_CHECK"

echo ""
echo -e "${YELLOW}🔍 Проверка переменных окружения backend:${NC}"
ssh_exec "docker exec agb_backend env | grep -E 'DATABASE|SECRET' 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

#!/bin/bash

# Скрипт для полного тестирования backend

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧪 Полное тестирование backend${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📊 Статус контейнеров:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" || true

echo ""
echo -e "${YELLOW}🧪 Тест health endpoint...${NC}"
HEALTH=$(ssh_exec "curl -s http://localhost:8000/health 2>&1" 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    echo -e "${GREEN}✅ Backend работает!${NC}"
    echo "   $HEALTH"
else
    echo -e "${RED}❌ Backend не работает${NC}"
    echo "   $HEALTH"
fi

echo ""
echo -e "${YELLOW}🔐 Тест входа...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход успешен!${NC}"
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    
    if [ ! -z "$TOKEN" ]; then
        echo ""
        echo -e "${YELLOW}📋 Тест получения паспортов...${NC}"
        PASSPORTS=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/?page=1&page_size=5' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$PASSPORTS" | grep -q "passports\|pagination"; then
            echo -e "${GREEN}✅ Паспорта загружаются!${NC}"
            echo "$PASSPORTS" | python3 -m json.tool 2>/dev/null | head -20 || echo "$PASSPORTS" | head -5
        else
            echo -e "${RED}❌ Ошибка загрузки паспортов${NC}"
            echo "$PASSPORTS"
        fi
        
        echo ""
        echo -e "${YELLOW}📋 Тест получения номенклатуры...${NC}"
        NOMENCLATURE=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/nomenclature/' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1 | head -3)
        
        if echo "$NOMENCLATURE" | grep -q "\["; then
            echo -e "${GREEN}✅ Номенклатура загружается!${NC}"
            COUNT=$(echo "$NOMENCLATURE" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
            echo "   Найдено записей: $COUNT"
        else
            echo -e "${RED}❌ Ошибка загрузки номенклатуры${NC}"
            echo "$NOMENCLATURE"
        fi
    fi
else
    echo -e "${RED}❌ Вход не работает${NC}"
    echo "   Ответ: $LOGIN_RESPONSE"
fi

echo ""
echo -e "${YELLOW}📋 Последние логи backend (10 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 10 2>&1" 2>&1 | tail -15

echo ""
echo -e "${GREEN}✅ Тестирование завершено!${NC}"
echo ""

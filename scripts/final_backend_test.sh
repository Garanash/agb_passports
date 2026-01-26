#!/bin/bash

# Финальный тест backend

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}✅ Финальный тест backend${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🧪 Тест health endpoint:${NC}"
HEALTH=$(ssh_exec "curl -s http://localhost:8000/health 2>&1" 2>&1)
echo "$HEALTH"

echo ""
echo -e "${YELLOW}🔐 Тест входа:${NC}"
LOGIN=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход работает${NC}"
    TOKEN=$(echo "$LOGIN" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    
    if [ ! -z "$TOKEN" ]; then
        echo ""
        echo -e "${YELLOW}📋 Тест получения паспортов:${NC}"
        PASSPORTS=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/?page=1&page_size=5' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$PASSPORTS" | grep -q '"passports"'; then
            PASSPORT_COUNT=$(echo "$PASSPORTS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('passports', [])))" 2>/dev/null || echo "?")
            TOTAL_COUNT=$(echo "$PASSPORTS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('pagination', {}).get('total_count', 0))" 2>/dev/null || echo "?")
            echo -e "${GREEN}✅ Паспорта загружаются${NC}"
            echo "   На странице: $PASSPORT_COUNT"
            echo "   Всего: $TOTAL_COUNT"
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
        
        echo ""
        echo -e "${YELLOW}🧪 Тест через nginx:${NC}"
        HEALTH_NGINX=$(ssh_exec "curl -s http://localhost/api/v1/passports/health 2>&1" 2>&1)
        if echo "$HEALTH_NGINX" | grep -q "healthy"; then
            echo -e "${GREEN}✅ API доступен через nginx${NC}"
        else
            echo -e "${RED}❌ API недоступен через nginx${NC}"
        fi
    fi
else
    echo -e "${RED}❌ Вход не работает${NC}"
fi

echo ""
echo -e "${YELLOW}📋 Статус контейнеров:${NC}"
ssh_exec "cd /root/agb_passports && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" | head -5

echo ""
echo -e "${GREEN}✅ Тест завершен!${NC}"
echo ""

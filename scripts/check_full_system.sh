#!/bin/bash

# Скрипт для полной проверки системы

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Полная проверка системы${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🧪 Тест API через nginx (health):${NC}"
HEALTH_NGINX=$(ssh_exec "curl -s http://localhost/api/v1/passports/health 2>&1" 2>&1)
if echo "$HEALTH_NGINX" | grep -q "healthy"; then
    echo -e "${GREEN}✅ API доступен через nginx${NC}"
    echo "   $HEALTH_NGINX"
else
    echo -e "${RED}❌ API недоступен через nginx${NC}"
    echo "   $HEALTH_NGINX"
fi

echo ""
echo -e "${YELLOW}🔐 Тест входа через nginx:${NC}"
LOGIN_NGINX=$(ssh_exec "curl -s -X POST http://localhost/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_NGINX" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход работает через nginx${NC}"
    TOKEN=$(echo "$LOGIN_NGINX" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    
    if [ ! -z "$TOKEN" ]; then
        echo ""
        echo -e "${YELLOW}📋 Тест получения паспортов через nginx:${NC}"
        PASSPORTS_NGINX=$(ssh_exec "curl -s -X GET 'http://localhost/api/v1/passports/?page=1&page_size=5' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$PASSPORTS_NGINX" | grep -q "passports\|\["; then
            PASSPORT_COUNT=$(echo "$PASSPORTS_NGINX" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('passports', [])) if isinstance(data, dict) else len(data) if isinstance(data, list) else 0)" 2>/dev/null || echo "?")
            echo -e "${GREEN}✅ Паспорта загружаются через nginx (найдено: $PASSPORT_COUNT)${NC}"
        else
            echo -e "${RED}❌ Ошибка загрузки паспортов через nginx${NC}"
            echo "$PASSPORTS_NGINX" | head -5
        fi
        
        echo ""
        echo -e "${YELLOW}📋 Тест получения номенклатуры через nginx:${NC}"
        NOMENCLATURE_NGINX=$(ssh_exec "curl -s -X GET 'http://localhost/api/v1/nomenclature/' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$NOMENCLATURE_NGINX" | grep -q "\["; then
            COUNT=$(echo "$NOMENCLATURE_NGINX" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
            echo -e "${GREEN}✅ Номенклатура загружается через nginx (найдено: $COUNT)${NC}"
        else
            echo -e "${RED}❌ Ошибка загрузки номенклатуры через nginx${NC}"
            echo "$NOMENCLATURE_NGINX" | head -5
        fi
    fi
else
    echo -e "${RED}❌ Вход не работает через nginx${NC}"
    echo "   Ответ: $LOGIN_NGINX" | head -3
fi

echo ""
echo -e "${YELLOW}📋 Логи nginx (последние 10 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs nginx --tail 10 2>&1" 2>&1 | tail -15 | grep -v "Warning"

echo ""
echo -e "${YELLOW}📋 Логи frontend (последние 10 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs frontend --tail 10 2>&1" 2>&1 | tail -15 | grep -v "Warning"

echo ""
echo -e "${YELLOW}🔍 Проверка ошибок в логах nginx:${NC}"
NGINX_ERRORS=$(ssh_exec "cd $SERVER_PATH && docker compose logs nginx 2>&1 | grep -i 'error\|502\|503\|504' | tail -5" 2>&1 | grep -v "Warning")
if [ ! -z "$NGINX_ERRORS" ]; then
    echo -e "${RED}❌ Найдены ошибки в nginx:${NC}"
    echo "$NGINX_ERRORS"
else
    echo -e "${GREEN}✅ Ошибок в nginx не найдено${NC}"
fi

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

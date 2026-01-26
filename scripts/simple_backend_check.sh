#!/bin/bash

# Простая проверка backend

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}✅ Простая проверка backend${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔐 Получение токена...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    echo -e "${GREEN}✅ Токен получен${NC}"
    
    if [ ! -z "$TOKEN" ]; then
        echo ""
        echo -e "${YELLOW}📋 Тест получения паспортов:${NC}"
        PASSPORTS=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/?page=1&page_size=3' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        # Сохраняем в файл для анализа
        echo "$PASSPORTS" > /tmp/passports_response.json
        
        if echo "$PASSPORTS" | grep -q '"passports"'; then
            echo -e "${GREEN}✅ Формат правильный (есть поле passports)${NC}"
            PASSPORT_COUNT=$(echo "$PASSPORTS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('passports', [])))" 2>/dev/null || echo "?")
            TOTAL_COUNT=$(echo "$PASSPORTS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('pagination', {}).get('total_count', 0))" 2>/dev/null || echo "?")
            echo "   Паспортов на странице: $PASSPORT_COUNT"
            echo "   Всего паспортов: $TOTAL_COUNT"
        elif echo "$PASSPORTS" | grep -q '\['; then
            echo -e "${RED}❌ Возвращается массив вместо объекта${NC}"
            echo "   Первые 100 символов:"
            echo "$PASSPORTS" | head -c 100
            echo "..."
        else
            echo -e "${RED}❌ Неожиданный формат${NC}"
            echo "$PASSPORTS" | head -5
        fi
        
        echo ""
        echo -e "${YELLOW}📋 Тест получения номенклатуры:${NC}"
        NOMENCLATURE=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/nomenclature/' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$NOMENCLATURE" | grep -q "\["; then
            COUNT=$(echo "$NOMENCLATURE" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
            echo -e "${GREEN}✅ Номенклатура загружается (найдено: $COUNT)${NC}"
        elif echo "$NOMENCLATURE" | grep -q "Internal Server Error"; then
            echo -e "${RED}❌ Internal Server Error при загрузке номенклатуры${NC}"
            echo "   Проверьте логи backend"
        else
            echo -e "${RED}❌ Ошибка загрузки номенклатуры${NC}"
            echo "$NOMENCLATURE" | head -5
        fi
    fi
else
    echo -e "${RED}❌ Не удалось получить токен${NC}"
fi

echo ""
echo -e "${YELLOW}📋 Последние ошибки в логах:${NC}"
ssh_exec "cd /root/agb_passports && docker compose logs backend --tail 20 2>&1 | grep -i 'error\|exception' | tail -5" 2>&1 | grep -v "Warning" | head -10

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

#!/bin/bash

# Скрипт для проверки формата ответа паспортов

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧪 Проверка формата ответа паспортов${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔐 Получение токена...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    
    if [ ! -z "$TOKEN" ]; then
        echo -e "${GREEN}✅ Токен получен${NC}"
        
        echo ""
        echo -e "${YELLOW}📋 Проверка формата ответа...${NC}"
        PASSPORTS_RESPONSE=$(ssh_exec "curl -s -X GET 'http://localhost/api/v1/passports/?page=1&page_size=5' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        # Сохраняем ответ во временный файл для анализа
        echo "$PASSPORTS_RESPONSE" > /tmp/passports_response.json
        
        # Проверяем формат
        if echo "$PASSPORTS_RESPONSE" | grep -q '"passports"'; then
            PASSPORT_COUNT=$(echo "$PASSPORTS_RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('passports', [])))" 2>/dev/null || echo "?")
            TOTAL_COUNT=$(echo "$PASSPORTS_RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('pagination', {}).get('total_count', 0))" 2>/dev/null || echo "?")
            
            if [ "$PASSPORT_COUNT" != "?" ] && [ "$TOTAL_COUNT" != "?" ]; then
                echo -e "${GREEN}✅ Формат правильный (с пагинацией)${NC}"
                echo "   Паспортов на странице: $PASSPORT_COUNT"
                echo "   Всего паспортов: $TOTAL_COUNT"
            else
                echo -e "${YELLOW}⚠️ Формат частично правильный${NC}"
                echo "$PASSPORTS_RESPONSE" | head -3
            fi
        elif echo "$PASSPORTS_RESPONSE" | grep -q '\['; then
            echo -e "${RED}❌ Формат неправильный (возвращается массив вместо объекта)${NC}"
            echo "   Первые 200 символов ответа:"
            echo "$PASSPORTS_RESPONSE" | head -c 200
            echo ""
        else
            echo -e "${RED}❌ Неожиданный формат ответа${NC}"
            echo "$PASSPORTS_RESPONSE" | head -5
        fi
    fi
else
    echo -e "${RED}❌ Не удалось получить токен${NC}"
fi

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

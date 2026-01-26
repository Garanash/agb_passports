#!/bin/bash

# Скрипт для полного тестирования API

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧪 Полное тестирование API${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔐 Получение токена...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    echo -e "${GREEN}✅ Токен получен${NC}"
    
    if [ ! -z "$TOKEN" ]; then
        echo ""
        echo -e "${YELLOW}📋 Тест получения паспортов с пагинацией:${NC}"
        PASSPORTS_RESPONSE=$(ssh_exec "curl -s -X GET 'http://localhost/api/v1/passports/?page=1&page_size=20' -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' 2>&1" 2>&1)
        
        if echo "$PASSPORTS_RESPONSE" | grep -q "passports"; then
            PASSPORT_COUNT=$(echo "$PASSPORTS_RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('passports', [])))" 2>/dev/null || echo "0")
            TOTAL_COUNT=$(echo "$PASSPORTS_RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('pagination', {}).get('total_count', 0))" 2>/dev/null || echo "0")
            echo -e "${GREEN}✅ Паспорта загружаются${NC}"
            echo "   На странице: $PASSPORT_COUNT"
            echo "   Всего: $TOTAL_COUNT"
            echo "   Формат ответа правильный (с пагинацией)"
        else
            echo -e "${RED}❌ Ошибка загрузки паспортов${NC}"
            echo "$PASSPORTS_RESPONSE" | head -10
        fi
        
        echo ""
        echo -e "${YELLOW}📋 Тест получения номенклатуры:${NC}"
        NOMENCLATURE_RESPONSE=$(ssh_exec "curl -s -X GET 'http://localhost/api/v1/nomenclature/' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$NOMENCLATURE_RESPONSE" | grep -q "\["; then
            COUNT=$(echo "$NOMENCLATURE_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
            echo -e "${GREEN}✅ Номенклатура загружается (найдено: $COUNT)${NC}"
        else
            echo -e "${RED}❌ Ошибка загрузки номенклатуры${NC}"
            echo "$NOMENCLATURE_RESPONSE" | head -5
        fi
        
        # Получаем ID первого паспорта для теста экспорта
        if [ ! -z "$PASSPORTS_RESPONSE" ] && echo "$PASSPORTS_RESPONSE" | grep -q "passports"; then
            PASSPORT_ID=$(echo "$PASSPORTS_RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); passports = data.get('passports', []); print(passports[0]['id'] if passports else '')" 2>/dev/null || echo "")
            
            if [ ! -z "$PASSPORT_ID" ] && [ "$PASSPORT_ID" != "None" ]; then
                echo ""
                echo -e "${YELLOW}🧪 Тест экспорта наклеек в DOCX:${NC}"
                DOCX_RESPONSE=$(ssh_exec "curl -s -X POST 'http://localhost/api/v1/passports/export/stickers/docx' -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '[$PASSPORT_ID]' -o /tmp/test_stickers.docx -w '%{http_code}' 2>&1" 2>&1 | tail -1)
                
                if [ "$DOCX_RESPONSE" = "200" ]; then
                    DOCX_SIZE=$(ssh_exec "ls -lh /tmp/test_stickers.docx 2>&1 | awk '{print \$5}'" 2>&1 | grep -v "Warning" || echo "0")
                    echo -e "${GREEN}✅ DOCX наклеек создается (размер: $DOCX_SIZE)${NC}"
                else
                    echo -e "${RED}❌ Ошибка создания DOCX наклеек (HTTP $DOCX_RESPONSE)${NC}"
                fi
            fi
        fi
    fi
else
    echo -e "${RED}❌ Не удалось получить токен${NC}"
    echo "   Ответ: $LOGIN_RESPONSE" | head -3
fi

echo ""
echo -e "${YELLOW}📋 Последние логи backend (5 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 5 2>&1" 2>&1 | tail -10 | grep -v "Warning"

echo ""
echo -e "${GREEN}✅ Тестирование завершено!${NC}"
echo ""

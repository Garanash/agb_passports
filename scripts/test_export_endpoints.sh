#!/bin/bash

# Скрипт для тестирования эндпоинтов экспорта

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧪 Тестирование эндпоинтов экспорта${NC}"
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
    
    # Получаем ID первого паспорта для теста
    echo ""
    echo -e "${YELLOW}📋 Получение списка паспортов...${NC}"
    PASSPORTS_JSON=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/?page=1&page_size=1' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
    
    PASSPORT_ID=$(echo "$PASSPORTS_JSON" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['passports'][0]['id'] if 'passports' in data and len(data['passports']) > 0 else data[0]['id'] if isinstance(data, list) and len(data) > 0 else '')" 2>/dev/null || echo "")
    
    if [ ! -z "$PASSPORT_ID" ] && [ "$PASSPORT_ID" != "None" ]; then
        echo -e "${GREEN}✅ Найден паспорт с ID: $PASSPORT_ID${NC}"
        
        echo ""
        echo -e "${YELLOW}🧪 Тест экспорта одного паспорта в PDF...${NC}"
        PDF_RESPONSE=$(ssh_exec "curl -s -X GET \"http://localhost:8000/api/v1/passports/$PASSPORT_ID/export/pdf\" -H 'Authorization: Bearer $TOKEN' -o /tmp/test_passport.pdf 2>&1 && echo 'OK' || echo 'FAILED'" 2>&1)
        if echo "$PDF_RESPONSE" | grep -q "OK"; then
            PDF_SIZE=$(ssh_exec "ls -lh /tmp/test_passport.pdf 2>&1 | awk '{print \$5}'" 2>&1 | grep -v "Warning" || echo "0")
            echo -e "${GREEN}✅ PDF паспорта создан (размер: $PDF_SIZE)${NC}"
        else
            echo -e "${RED}❌ Ошибка создания PDF паспорта${NC}"
            echo "$PDF_RESPONSE"
        fi
        
        echo ""
        echo -e "${YELLOW}🧪 Тест экспорта наклеек в PDF...${NC}"
        STICKERS_RESPONSE=$(ssh_exec "curl -s -X POST 'http://localhost:8000/api/v1/passports/export/stickers/pdf' -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '[$PASSPORT_ID]' -o /tmp/test_stickers.pdf 2>&1 && echo 'OK' || echo 'FAILED'" 2>&1)
        if echo "$STICKERS_RESPONSE" | grep -q "OK"; then
            STICKERS_SIZE=$(ssh_exec "ls -lh /tmp/test_stickers.pdf 2>&1 | awk '{print \$5}'" 2>&1 | grep -v "Warning" || echo "0")
            echo -e "${GREEN}✅ PDF наклеек создан (размер: $STICKERS_SIZE)${NC}"
        else
            echo -e "${RED}❌ Ошибка создания PDF наклеек${NC}"
            echo "$STICKERS_RESPONSE"
        fi
        
        echo ""
        echo -e "${YELLOW}🧪 Тест экспорта наклеек в DOCX...${NC}"
        DOCX_RESPONSE=$(ssh_exec "curl -s -X POST 'http://localhost:8000/api/v1/passports/export/stickers/docx' -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '[$PASSPORT_ID]' -o /tmp/test_stickers.docx 2>&1 && echo 'OK' || echo 'FAILED'" 2>&1)
        if echo "$DOCX_RESPONSE" | grep -q "OK"; then
            DOCX_SIZE=$(ssh_exec "ls -lh /tmp/test_stickers.docx 2>&1 | awk '{print \$5}'" 2>&1 | grep -v "Warning" || echo "0")
            echo -e "${GREEN}✅ DOCX наклеек создан (размер: $DOCX_SIZE)${NC}"
        else
            echo -e "${RED}❌ Ошибка создания DOCX наклеек${NC}"
            echo "$DOCX_RESPONSE"
        fi
        
    else
        echo -e "${RED}❌ Не удалось получить ID паспорта${NC}"
        echo "Ответ: $PASSPORTS_JSON"
    fi
else
    echo -e "${RED}❌ Не удалось получить токен${NC}"
    echo "Ответ: $LOGIN_RESPONSE"
fi

echo ""
echo -e "${YELLOW}📋 Последние логи backend после тестов...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 30 2>&1" 2>&1 | tail -35

echo ""
echo -e "${GREEN}✅ Тестирование завершено!${NC}"
echo ""

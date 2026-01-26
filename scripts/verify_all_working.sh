#!/bin/bash

# Скрипт для полной проверки работоспособности системы

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Полная проверка работоспособности системы${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📊 Статус всех контейнеров:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" || true

echo ""
echo -e "${YELLOW}🧪 Тест health endpoint backend...${NC}"
HEALTH=$(ssh_exec "curl -s http://localhost:8000/health 2>&1" 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    echo -e "${GREEN}✅ Backend работает!${NC}"
else
    echo -e "${RED}❌ Backend не работает${NC}"
    echo "   $HEALTH"
fi

echo ""
echo -e "${YELLOW}🧪 Тест health endpoint через nginx...${NC}"
HEALTH_NGINX=$(ssh_exec "curl -s http://localhost/api/v1/passports/health 2>&1" 2>&1)
if echo "$HEALTH_NGINX" | grep -q "healthy"; then
    echo -e "${GREEN}✅ API доступен через nginx!${NC}"
else
    echo -e "${RED}❌ API недоступен через nginx${NC}"
    echo "   $HEALTH_NGINX"
fi

echo ""
echo -e "${YELLOW}🔐 Тест входа...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход работает!${NC}"
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    
    if [ ! -z "$TOKEN" ]; then
        echo ""
        echo -e "${YELLOW}📋 Тест получения паспортов...${NC}"
        PASSPORTS=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/?page=1&page_size=5' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$PASSPORTS" | grep -q "passports"; then
            PASSPORT_COUNT=$(echo "$PASSPORTS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('passports', [])))" 2>/dev/null || echo "0")
            TOTAL_COUNT=$(echo "$PASSPORTS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('pagination', {}).get('total_count', 0))" 2>/dev/null || echo "0")
            echo -e "${GREEN}✅ Паспорта загружаются!${NC}"
            echo "   Получено паспортов на странице: $PASSPORT_COUNT"
            echo "   Всего паспортов: $TOTAL_COUNT"
        else
            echo -e "${RED}❌ Ошибка загрузки паспортов${NC}"
            echo "$PASSPORTS" | head -5
        fi
        
        echo ""
        echo -e "${YELLOW}📋 Тест получения номенклатуры...${NC}"
        NOMENCLATURE=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/nomenclature/' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$NOMENCLATURE" | grep -q "\["; then
            COUNT=$(echo "$NOMENCLATURE" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
            echo -e "${GREEN}✅ Номенклатура загружается!${NC}"
            echo "   Найдено записей: $COUNT"
        else
            echo -e "${RED}❌ Ошибка загрузки номенклатуры${NC}"
            echo "$NOMENCLATURE" | head -5
        fi
        
        # Получаем ID первого паспорта для теста экспорта
        if [ ! -z "$PASSPORTS" ] && echo "$PASSPORTS" | grep -q "passports"; then
            PASSPORT_ID=$(echo "$PASSPORTS" | python3 -c "import sys, json; data = json.load(sys.stdin); passports = data.get('passports', []); print(passports[0]['id'] if passports else '')" 2>/dev/null || echo "")
            
            if [ ! -z "$PASSPORT_ID" ] && [ "$PASSPORT_ID" != "None" ]; then
                echo ""
                echo -e "${YELLOW}🧪 Тест экспорта паспорта в PDF...${NC}"
                PDF_TEST=$(ssh_exec "curl -s -X GET \"http://localhost:8000/api/v1/passports/$PASSPORT_ID/export/pdf\" -H 'Authorization: Bearer $TOKEN' -o /tmp/test_passport.pdf -w '%{http_code}' 2>&1" 2>&1 | tail -1)
                if [ "$PDF_TEST" = "200" ]; then
                    PDF_SIZE=$(ssh_exec "ls -lh /tmp/test_passport.pdf 2>&1 | awk '{print \$5}'" 2>&1 | grep -v "Warning" || echo "0")
                    echo -e "${GREEN}✅ PDF паспорта создается!${NC}"
                    echo "   Размер файла: $PDF_SIZE"
                else
                    echo -e "${RED}❌ Ошибка создания PDF паспорта (HTTP $PDF_TEST)${NC}"
                fi
                
                echo ""
                echo -e "${YELLOW}🧪 Тест экспорта наклеек в DOCX...${NC}"
                DOCX_TEST=$(ssh_exec "curl -s -X POST 'http://localhost:8000/api/v1/passports/export/stickers/docx' -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '[$PASSPORT_ID]' -o /tmp/test_stickers.docx -w '%{http_code}' 2>&1" 2>&1 | tail -1)
                if [ "$DOCX_TEST" = "200" ]; then
                    DOCX_SIZE=$(ssh_exec "ls -lh /tmp/test_stickers.docx 2>&1 | awk '{print \$5}'" 2>&1 | grep -v "Warning" || echo "0")
                    echo -e "${GREEN}✅ DOCX наклеек создается!${NC}"
                    echo "   Размер файла: $DOCX_SIZE"
                else
                    echo -e "${RED}❌ Ошибка создания DOCX наклеек (HTTP $DOCX_TEST)${NC}"
                fi
            fi
        fi
    fi
else
    echo -e "${RED}❌ Вход не работает${NC}"
    echo "   Ответ: $LOGIN_RESPONSE" | head -3
fi

echo ""
echo -e "${YELLOW}📋 Последние логи backend (5 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 5 2>&1" 2>&1 | tail -10

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""
echo -e "${BLUE}💡 Если все тесты прошли успешно, но в браузере все еще не работает,${NC}"
echo -e "${BLUE}   попробуйте обновить страницу (Ctrl+F5 или Cmd+Shift+R)${NC}"
echo ""

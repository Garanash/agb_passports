#!/bin/bash

# Финальный комплексный тест

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}✅ Финальный комплексный тест${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📊 Статус контейнеров:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" | head -5

echo ""
echo -e "${YELLOW}🔐 Получение токена...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    echo -e "${GREEN}✅ Токен получен${NC}"
    
    if [ ! -z "$TOKEN" ]; then
        # Получаем ID первого паспорта
        echo ""
        echo -e "${YELLOW}📋 Получение ID паспорта...${NC}"
        PASSPORTS_RESPONSE=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/?page=1&page_size=1' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        PASSPORT_ID=$(echo "$PASSPORTS_RESPONSE" | python3 -c "import sys, json; data = json.load(sys.stdin); passports = data.get('passports', []); print(passports[0]['id'] if passports else '')" 2>/dev/null || echo "")
        
        if [ ! -z "$PASSPORT_ID" ] && [ "$PASSPORT_ID" != "None" ]; then
            echo -e "${GREEN}✅ Найден паспорт с ID: $PASSPORT_ID${NC}"
            
            echo ""
            echo -e "${YELLOW}🧪 Тест экспорта паспорта в PDF (с логотипом)...${NC}"
            PDF_TEST=$(ssh_exec "curl -s -X GET \"http://localhost:8000/api/v1/passports/$PASSPORT_ID/export/pdf\" -H 'Authorization: Bearer $TOKEN' -o /tmp/test_passport_final.pdf -w '%{http_code}' 2>&1" 2>&1 | tail -1)
            
            if [ "$PDF_TEST" = "200" ]; then
                PDF_SIZE=$(ssh_exec "ls -lh /tmp/test_passport_final.pdf 2>&1 | awk '{print \$5}'" 2>&1 | grep -v "Warning" || echo "0")
                echo -e "${GREEN}✅ PDF паспорта создан (размер: $PDF_SIZE)${NC}"
            else
                echo -e "${RED}❌ Ошибка создания PDF (HTTP $PDF_TEST)${NC}"
            fi
            
            echo ""
            echo -e "${YELLOW}🧪 Тест экспорта наклеек в DOCX (с логотипом и штрихкодами)...${NC}"
            DOCX_TEST=$(ssh_exec "curl -s -X POST 'http://localhost:8000/api/v1/passports/export/stickers/docx' -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '[$PASSPORT_ID]' -o /tmp/test_stickers_final.docx -w '%{http_code}' 2>&1" 2>&1 | tail -1)
            
            if [ "$DOCX_TEST" = "200" ]; then
                DOCX_SIZE=$(ssh_exec "ls -lh /tmp/test_stickers_final.docx 2>&1 | awk '{print \$5}'" 2>&1 | grep -v "Warning" || echo "0")
                echo -e "${GREEN}✅ DOCX наклеек создан (размер: $DOCX_SIZE)${NC}"
                
                # Проверяем логи
                echo ""
                echo -e "${YELLOW}📋 Проверка логов на использование логотипа и штрихкодов:${NC}"
                LOGO_LOGS=$(ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 50 2>&1 | grep -i 'логотип\|logo' | tail -5" 2>&1 | grep -v "Warning")
                if [ ! -z "$LOGO_LOGS" ]; then
                    echo -e "${GREEN}✅ Логотип используется:${NC}"
                    echo "$LOGO_LOGS"
                fi
                
                BARCODE_LOGS=$(ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 50 2>&1 | grep -i 'штрихкод\|barcode\|stock_code\|serial_number_code' | tail -5" 2>&1 | grep -v "Warning")
                if [ ! -z "$BARCODE_LOGS" ]; then
                    echo -e "${GREEN}✅ Штрихкоды используются:${NC}"
                    echo "$BARCODE_LOGS"
                else
                    echo -e "${YELLOW}⚠️ Сообщений о штрихкодах не найдено в логах${NC}"
                fi
                
                TEMPLATE_LOGS=$(ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 50 2>&1 | grep -i 'шаблон\|template\|generate_from_template' | tail -5" 2>&1 | grep -v "Warning")
                if [ ! -z "$TEMPLATE_LOGS" ]; then
                    echo -e "${GREEN}✅ Шаблон используется:${NC}"
                    echo "$TEMPLATE_LOGS"
                fi
            else
                echo -e "${RED}❌ Ошибка создания DOCX (HTTP $DOCX_TEST)${NC}"
            fi
        fi
    fi
fi

echo ""
echo -e "${YELLOW}📋 Последние логи backend (10 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 10 2>&1" 2>&1 | tail -15 | grep -v "Warning"

echo ""
echo -e "${GREEN}✅ Тест завершен!${NC}"
echo ""

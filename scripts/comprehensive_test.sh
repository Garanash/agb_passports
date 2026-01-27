#!/bin/bash

# Комплексное тестирование всех функций приложения

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧪 Комплексное тестирование приложения${NC}"
echo ""

ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

# Получаем токен
echo -e "${YELLOW}🔑 Получение токена...${NC}"
TOKEN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1 | grep -v "Warning")
TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ Не удалось получить токен${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Токен получен${NC}"
echo ""

# Тест 1: Получение паспортов
echo -e "${YELLOW}📋 Тест 1: Получение паспортов...${NC}"
RESPONSE=$(ssh_exec "curl -s 'http://localhost:8000/api/v1/passports/?page=1&page_size=20' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1 | grep -v "Warning")
if echo "$RESPONSE" | grep -q "passports\|total\|items"; then
    echo -e "${GREEN}✅ Работает${NC}"
else
    echo -e "${RED}❌ Ошибка${NC}"
fi

# Тест 2: Получение номенклатуры
echo -e "${YELLOW}📦 Тест 2: Получение номенклатуры...${NC}"
RESPONSE=$(ssh_exec "curl -s 'http://localhost:8000/api/v1/nomenclature/?page=1&page_size=20' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1 | grep -v "Warning")
if echo "$RESPONSE" | grep -q "items\|\[\]"; then
    echo -e "${GREEN}✅ Работает${NC}"
else
    echo -e "${RED}❌ Ошибка${NC}"
fi

# Тест 3: Получение шаблонов
echo -e "${YELLOW}📄 Тест 3: Получение шаблонов...${NC}"
RESPONSE=$(ssh_exec "curl -s 'http://localhost:8000/api/v1/templates/' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1 | grep -v "Warning")
if echo "$RESPONSE" | grep -q "type\|sticker\|passport"; then
    echo -e "${GREEN}✅ Работает${NC}"
else
    echo -e "${RED}❌ Ошибка${NC}"
fi

# Тест 4: Получение логотипа
echo -e "${YELLOW}🖼️  Тест 4: Получение логотипа...${NC}"
RESPONSE=$(ssh_exec "curl -s -o /dev/null -w '%{http_code}' 'http://localhost:8000/api/v1/templates/logo' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1 | grep -v "Warning")
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "404" ]; then
    echo -e "${GREEN}✅ Работает (HTTP $RESPONSE)${NC}"
else
    echo -e "${RED}❌ Ошибка (HTTP $RESPONSE)${NC}"
fi

echo ""
echo -e "${GREEN}✅ Тестирование завершено!${NC}"

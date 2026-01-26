#!/bin/bash

# Глубокая проверка backend

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Глубокая проверка backend${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📊 Детальный статус контейнеров:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" || true

echo ""
echo -e "${YELLOW}📋 Последние 50 строк логов backend:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 50 2>&1" 2>&1 | tail -55

echo ""
echo -e "${YELLOW}🔍 Все ошибки в логах backend:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend 2>&1 | grep -i 'error\|exception\|traceback\|failed\|fatal\|warning' | tail -20" 2>&1 | tail -25

echo ""
echo -e "${YELLOW}🧪 Тест health endpoint (прямо на backend):${NC}"
HEALTH_DIRECT=$(ssh_exec "curl -s http://localhost:8000/health 2>&1" 2>&1)
echo "$HEALTH_DIRECT"

echo ""
echo -e "${YELLOW}🧪 Тест health endpoint (через nginx):${NC}"
HEALTH_NGINX=$(ssh_exec "curl -s http://localhost/api/v1/passports/health 2>&1" 2>&1)
echo "$HEALTH_NGINX"

echo ""
echo -e "${YELLOW}🔐 Тест входа:${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)
echo "$LOGIN_RESPONSE" | head -3

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    
    if [ ! -z "$TOKEN" ]; then
        echo -e "${GREEN}✅ Токен получен${NC}"
        
        echo ""
        echo -e "${YELLOW}📋 Тест получения паспортов (с подробным выводом):${NC}"
        PASSPORTS_RESPONSE=$(ssh_exec "curl -s -v -X GET 'http://localhost:8000/api/v1/passports/?page=1&page_size=5' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        HTTP_CODE=$(echo "$PASSPORTS_RESPONSE" | grep -i "< HTTP" | tail -1 | awk '{print $3}')
        echo "HTTP код: $HTTP_CODE"
        
        BODY=$(echo "$PASSPORTS_RESPONSE" | sed -n '/^{/,$p')
        
        if echo "$BODY" | grep -q '"passports"'; then
            PASSPORT_COUNT=$(echo "$BODY" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('passports', [])))" 2>/dev/null || echo "?")
            echo -e "${GREEN}✅ Паспорта загружаются (найдено: $PASSPORT_COUNT)${NC}"
            echo "Первые 200 символов ответа:"
            echo "$BODY" | head -c 200
            echo "..."
        elif echo "$BODY" | grep -q '\['; then
            echo -e "${RED}❌ Возвращается массив вместо объекта с пагинацией${NC}"
            echo "Первые 200 символов:"
            echo "$BODY" | head -c 200
            echo "..."
        else
            echo -e "${RED}❌ Неожиданный формат ответа${NC}"
            echo "$BODY" | head -10
        fi
        
        echo ""
        echo -e "${YELLOW}📋 Тест получения номенклатуры:${NC}"
        NOMENCLATURE_RESPONSE=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/nomenclature/' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$NOMENCLATURE_RESPONSE" | grep -q "\["; then
            COUNT=$(echo "$NOMENCLATURE_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
            echo -e "${GREEN}✅ Номенклатура загружается (найдено: $COUNT)${NC}"
        else
            echo -e "${RED}❌ Ошибка загрузки номенклатуры${NC}"
            echo "$NOMENCLATURE_RESPONSE" | head -5
        fi
    fi
else
    echo -e "${RED}❌ Вход не работает${NC}"
    echo "$LOGIN_RESPONSE"
fi

echo ""
echo -e "${YELLOW}🔍 Проверка подключения к БД из контейнера:${NC}"
DB_TEST=$(ssh_exec "docker exec agb_backend python3 -c \"
import os
os.environ['DATABASE_URL'] = 'postgresql://postgres:password@postgres:5432/agb_passports'
from sqlalchemy import create_engine, text
try:
    engine = create_engine(os.environ['DATABASE_URL'])
    with engine.connect() as conn:
        result = conn.execute(text('SELECT COUNT(*) FROM ved_passports'))
        count = result.scalar()
        print(f'✅ Подключение к БД работает, найдено паспортов: {count}')
except Exception as e:
    print(f'❌ Ошибка подключения к БД: {e}')
\" 2>&1" 2>&1 | grep -v "Warning")
echo "$DB_TEST"

echo ""
echo -e "${YELLOW}🔍 Проверка переменных окружения:${NC}"
ssh_exec "docker exec agb_backend env | grep -E 'DATABASE|SECRET|PYTHON' 2>&1" 2>&1 | grep -v "Warning" | head -10

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

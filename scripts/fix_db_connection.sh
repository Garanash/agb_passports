#!/bin/bash

# Скрипт для исправления подключения к БД

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление подключения к БД${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔑 Установка правильного пароля PostgreSQL...${NC}"
ssh_exec "docker exec agb_postgres psql -U postgres -c \"ALTER ROLE postgres WITH PASSWORD 'password';\" 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🧪 Проверка подключения к БД...${NC}"
DB_TEST=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c 'SELECT COUNT(*) FROM ved_passports;' 2>&1" 2>&1 | grep -v "Warning" | head -5)
echo "$DB_TEST"

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (10 секунд)...${NC}"
sleep 10

echo ""
echo -e "${YELLOW}📋 Статус backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps backend 2>&1" 2>&1 | grep -E "NAME|agb_backend" || true

echo ""
echo -e "${YELLOW}📋 Последние логи backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 15 2>&1" 2>&1 | tail -20 | grep -v "Warning"

echo ""
echo -e "${YELLOW}🧪 Тест подключения к БД из backend...${NC}"
DB_CONNECTION_TEST=$(ssh_exec "docker exec agb_backend python3 -c \"
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
echo "$DB_CONNECTION_TEST"

echo ""
echo -e "${YELLOW}🧪 Тест получения паспортов через API...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    
    if [ ! -z "$TOKEN" ]; then
        PASSPORTS_TEST=$(ssh_exec "curl -s -X GET 'http://localhost:8000/api/v1/passports/?page=1&page_size=5' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1)
        
        if echo "$PASSPORTS_TEST" | grep -q '"passports"'; then
            PASSPORT_COUNT=$(echo "$PASSPORTS_TEST" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('passports', [])))" 2>/dev/null || echo "?")
            echo -e "${GREEN}✅ Паспорта загружаются через API (найдено: $PASSPORT_COUNT)${NC}"
        else
            echo -e "${RED}❌ Ошибка загрузки паспортов${NC}"
            echo "$PASSPORTS_TEST" | head -5
        fi
    fi
fi

echo ""
echo -e "${GREEN}✅ Исправление завершено!${NC}"
echo ""

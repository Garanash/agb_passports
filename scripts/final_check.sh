#!/bin/bash

# Финальная проверка работоспособности приложения

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Финальная проверка работоспособности приложения${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📊 Статус всех контейнеров:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps 2>&1" 2>&1 | grep -E "NAME|agb_" || true

echo ""
echo -e "${YELLOW}🔍 Проверка доступности сервисов:${NC}"

# Проверка backend health
echo -n "Backend Health: "
HEALTH=$(ssh_exec "curl -s http://localhost:8000/health 2>/dev/null || echo 'ERROR'" 2>&1)
if echo "$HEALTH" | grep -q "healthy\|status"; then
    echo -e "${GREEN}✅ Работает${NC}"
    echo "   Ответ: $HEALTH"
else
    echo -e "${RED}❌ Ошибка${NC}"
fi

# Проверка backend API docs
echo -n "Backend API Docs: "
DOCS=$(ssh_exec "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/docs 2>/dev/null || echo '000'" 2>&1)
if echo "$DOCS" | grep -q "200"; then
    echo -e "${GREEN}✅ Доступен (HTTP $DOCS)${NC}"
else
    echo -e "${RED}❌ Недоступен (HTTP $DOCS)${NC}"
fi

# Проверка frontend через nginx
echo -n "Frontend через Nginx: "
FRONTEND=$(ssh_exec "curl -s -o /dev/null -w '%{http_code}' http://localhost 2>/dev/null || echo '000'" 2>&1)
if echo "$FRONTEND" | grep -qE "200|301|302"; then
    echo -e "${GREEN}✅ Доступен (HTTP $FRONTEND)${NC}"
else
    echo -e "${RED}❌ Недоступен (HTTP $FRONTEND)${NC}"
fi

# Проверка API через nginx
echo -n "API через Nginx: "
API=$(ssh_exec "curl -s -o /dev/null -w '%{http_code}' http://localhost/api/v1/passports/health 2>/dev/null || echo '000'" 2>&1)
if echo "$API" | grep -qE "200|401|403"; then
    echo -e "${GREEN}✅ Доступен (HTTP $API)${NC}"
else
    echo -e "${RED}❌ Недоступен (HTTP $API)${NC}"
fi

echo ""
echo -e "${YELLOW}📋 Проверка подключения к базе данных:${NC}"
if ssh_exec "docker exec agb_postgres pg_isready -U postgres > /dev/null 2>&1" 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL готов к подключениям${NC}"
else
    echo -e "${RED}❌ PostgreSQL не готов${NC}"
fi

echo ""
echo -e "${YELLOW}📋 Проверка наличия пользователей в БД:${NC}"
USERS=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c 'SELECT COUNT(*) FROM users;' 2>/dev/null || echo '0'" 2>&1 | tr -d ' ')
if [ "$USERS" -gt "0" ]; then
    echo -e "${GREEN}✅ В базе данных есть пользователи ($USERS)${NC}"
else
    echo -e "${YELLOW}⚠️  В базе данных нет пользователей${NC}"
fi

echo ""
echo -e "${BLUE}🌐 Приложение доступно по адресам:${NC}"
echo "   🌍 Frontend: http://185.247.17.188"
echo "   🔧 Backend API: http://185.247.17.188:8000"
echo "   📚 API Docs: http://185.247.17.188:8000/docs"
echo ""
echo -e "${YELLOW}🔐 Учетные данные по умолчанию:${NC}"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

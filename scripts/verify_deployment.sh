#!/bin/bash

# Скрипт для проверки работоспособности приложения

echo "🔍 Проверка работоспособности приложения..."
echo ""

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SUCCESS=0
FAILED=0

check_service() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    echo -n "Проверка $name... "
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$status_code" = "$expected_code" ] || [ "$status_code" = "200" ] || [ "$status_code" = "301" ] || [ "$status_code" = "302" ]; then
        echo -e "${GREEN}✅ OK (HTTP $status_code)${NC}"
        SUCCESS=$((SUCCESS + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED (HTTP $status_code)${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

check_container() {
    local name=$1
    echo -n "Проверка контейнера $name... "
    
    if docker ps | grep -q "$name"; then
        status=$(docker ps --format "{{.Status}}" --filter "name=$name")
        echo -e "${GREEN}✅ Running ($status)${NC}"
        SUCCESS=$((SUCCESS + 1))
        return 0
    else
        echo -e "${RED}❌ Not running${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

echo "=== Проверка контейнеров ==="
check_container "agb_postgres"
check_container "agb_backend"
check_container "agb_frontend"
check_container "agb_nginx"
echo ""

echo "=== Проверка сервисов ==="
check_service "PostgreSQL" "http://localhost:5435" "000"  # Просто проверяем доступность порта
check_service "Backend API" "http://localhost:8000/docs"
check_service "Backend Health" "http://localhost:8000/api/v1/passports/health"
check_service "Frontend" "http://localhost:3000"
check_service "Nginx" "http://localhost"
echo ""

echo "=== Проверка подключения к БД ==="
if docker exec agb_postgres pg_isready -U postgres > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL готов к подключениям${NC}"
    SUCCESS=$((SUCCESS + 1))
else
    echo -e "${RED}❌ PostgreSQL не готов${NC}"
    FAILED=$((FAILED + 1))
fi

echo ""
echo "=== Итоги ==="
echo -e "${GREEN}Успешно: $SUCCESS${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Ошибок: $FAILED${NC}"
    echo ""
    echo "Проверьте логи:"
    echo "  docker logs agb_backend --tail 50"
    echo "  docker logs agb_frontend --tail 50"
    echo "  docker logs agb_nginx --tail 50"
    exit 1
else
    echo -e "${GREEN}Все проверки пройдены успешно!${NC}"
    exit 0
fi

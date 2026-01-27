#!/bin/bash

# Полная пересборка контейнеров backend и frontend на сервере

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔨 Полная пересборка контейнеров backend и frontend${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🛑 Шаг 1: Остановка и удаление контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose stop backend frontend" 2>&1 | grep -v "Warning" || true
ssh_exec "cd $SERVER_PATH && docker compose rm -f backend frontend" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Контейнеры остановлены и удалены${NC}"
echo ""

echo -e "${YELLOW}🗑️  Шаг 2: Удаление образов...${NC}"
ssh_exec "docker rmi agb_passports-backend agb_passports-frontend 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Образы удалены${NC}"
echo ""

echo -e "${YELLOW}🔨 Шаг 3: Пересборка контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose build --no-cache backend frontend" 2>&1 | grep -v "Warning" | tail -20
echo ""

echo -e "${YELLOW}🚀 Шаг 4: Запуск контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose up -d backend frontend" 2>&1 | grep -v "Warning" || true
echo ""

echo -e "${YELLOW}⏳ Шаг 5: Ожидание запуска сервисов...${NC}"
sleep 15

echo -e "${YELLOW}📊 Шаг 6: Проверка статуса...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps" 2>&1 | grep -v "Warning" | tail -6 || true
echo ""

echo -e "${YELLOW}🧪 Шаг 7: Тест backend...${NC}"
sleep 5
HEALTH=$(ssh_exec "curl -s http://localhost:8000/api/v1/health 2>&1" 2>&1 | grep -v "Warning" || echo "ERROR")
if echo "$HEALTH" | grep -q "ok\|healthy"; then
    echo -e "${GREEN}✅ Backend работает${NC}"
else
    echo -e "${YELLOW}⚠️  Backend может еще запускаться (проверьте логи)${NC}"
fi
echo ""

echo -e "${YELLOW}📋 Шаг 8: Последние логи backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs --tail=10 backend 2>&1 | tail -10" 2>&1 | grep -v "Warning" || true
echo ""

echo -e "${GREEN}✅ Пересборка завершена!${NC}"
echo ""
echo -e "${BLUE}Проверьте статус:${NC}"
echo "  docker compose ps"
echo "  docker compose logs backend"
echo "  docker compose logs frontend"

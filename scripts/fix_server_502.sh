#!/bin/bash

# Скрипт для исправления проблемы 502 Bad Gateway на сервере

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление проблемы 502 Bad Gateway${NC}"
echo ""

SERVER="root@185.247.17.188"
SERVER_PATH="/root/agb_passports"

# Функция для выполнения команд на сервере
ssh_exec() {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📋 Шаг 1: Проверка статуса контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose -f docker-compose.production.yml ps"

echo ""
echo -e "${YELLOW}📋 Шаг 2: Проверка логов...${NC}"
echo -e "${BLUE}Backend logs:${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose -f docker-compose.production.yml logs backend --tail 20"

echo ""
echo -e "${BLUE}Frontend logs:${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose -f docker-compose.production.yml logs frontend --tail 20"

echo ""
echo -e "${BLUE}Nginx logs:${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose -f docker-compose.production.yml logs nginx --tail 20"

echo ""
echo -e "${YELLOW}📋 Шаг 3: Проверка сети Docker...${NC}"
ssh_exec "docker network inspect agb_network 2>/dev/null | grep -A 5 'Containers' || echo 'Сеть не найдена'"

echo ""
echo -e "${YELLOW}📋 Шаг 4: Перезапуск контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose -f docker-compose.production.yml down"
echo "Ожидание 3 секунды..."
sleep 3
ssh_exec "cd $SERVER_PATH && docker-compose -f docker-compose.production.yml up -d"

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска контейнеров (15 секунд)...${NC}"
sleep 15

echo ""
echo -e "${YELLOW}📋 Шаг 5: Проверка статуса после перезапуска...${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose -f docker-compose.production.yml ps"

echo ""
echo -e "${YELLOW}📋 Шаг 6: Проверка подключения из nginx к backend...${NC}"
ssh_exec "docker exec agb_nginx_prod wget -q -O- http://backend:8000/health 2>&1 || echo '❌ Backend недоступен'"

echo ""
echo -e "${YELLOW}📋 Шаг 7: Проверка подключения из nginx к frontend...${NC}"
ssh_exec "docker exec agb_nginx_prod wget -q -O- http://frontend:3000/ 2>&1 | head -5 || echo '❌ Frontend недоступен'"

echo ""
echo -e "${YELLOW}📋 Шаг 8: Финальная проверка...${NC}"
echo "Проверка health endpoint:"
curl -s http://185.247.17.188/health || echo "❌ Health check не работает"

echo ""
echo "Проверка главной страницы:"
curl -s -o /dev/null -w "%{http_code}" http://185.247.17.188/ && echo " - Главная страница" || echo "❌ Главная страница не работает"

echo ""
echo -e "${GREEN}✅ Диагностика завершена${NC}"
echo ""
echo -e "${BLUE}Для просмотра логов выполните:${NC}"
echo "ssh $SERVER 'cd $SERVER_PATH && docker-compose -f docker-compose.production.yml logs --tail 50'"

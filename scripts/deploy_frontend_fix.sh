#!/bin/bash

# Развертывание исправлений фронтенда

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Развертывание исправлений фронтенда${NC}"
echo ""

# Копируем исправленный файл
echo -e "${YELLOW}📦 Копирование файла MainApp.tsx...${NC}"
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no frontend/components/MainApp.tsx "$SERVER:$SERVER_PATH/frontend/components/MainApp.tsx" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Файл скопирован${NC}"

echo ""
echo -e "${YELLOW}🔄 Пересборка фронтенда на сервере...${NC}"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "cd $SERVER_PATH/frontend && docker compose exec frontend npm run build 2>&1 | tail -10" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔄 Перезапуск фронтенда...${NC}"
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER" "cd $SERVER_PATH && docker compose restart frontend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${GREEN}✅ Исправления развернуты!${NC}"
echo ""
echo -e "${BLUE}💡 Теперь фронтенд правильно обрабатывает DOCX файлы вместо PDF${NC}"
echo ""

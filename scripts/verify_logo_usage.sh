#!/bin/bash

# Скрипт для проверки использования логотипа

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка использования логотипа${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}⏳ Ожидание полного запуска backend (10 секунд)...${NC}"
sleep 10

echo ""
echo -e "${YELLOW}🐍 Тест функции create_logo_image...${NC}"
ssh_exec "docker exec agb_backend python3 -c \"
import sys
sys.path.insert(0, '/app')
from backend.utils.pdf_generator import create_logo_image
import os

print('🔍 Поиск логотипа...')
logo_path = create_logo_image()

if logo_path:
    print(f'✅ Логотип найден: {logo_path}')
    if os.path.exists(logo_path):
        size = os.path.getsize(logo_path)
        print(f'✅ Файл существует, размер: {size} байт')
    else:
        print('❌ Файл не существует по указанному пути')
else:
    print('❌ Логотип не найден')
\" 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}📋 Проверка путей к логотипу...${NC}"
ssh_exec "docker exec agb_backend bash -c \"
echo 'Проверка путей:'
echo '1. /app/backend/utils/templates/logo.png:'
ls -lh /app/backend/utils/templates/logo.png 2>&1 || echo '  Не найден'
echo ''
echo '2. /app/templates/logo.png:'
ls -lh /app/templates/logo.png 2>&1 || echo '  Не найден'
\" 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

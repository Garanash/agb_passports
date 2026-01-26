#!/bin/bash

# Скрипт для тестирования использования логотипа

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 Тестирование использования логотипа${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔍 Проверка логотипа на сервере...${NC}"
ssh_exec "ls -lh $SERVER_PATH/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "Логотип не найден"

echo ""
echo -e "${YELLOW}🔍 Проверка логотипа в контейнере...${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "Логотип не найден в контейнере"

echo ""
echo -e "${YELLOW}🐍 Тест функции create_logo_image в контейнере...${NC}"
ssh_exec "docker exec agb_backend python3 -c \"
import sys
sys.path.insert(0, '/app')
from backend.utils.pdf_generator import create_logo_image
logo_path = create_logo_image()
print(f'Логотип найден: {logo_path}')
if logo_path:
    import os
    if os.path.exists(logo_path):
        size = os.path.getsize(logo_path)
        print(f'Размер файла: {size} байт')
    else:
        print('Файл не существует')
\" 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${GREEN}✅ Тестирование завершено!${NC}"
echo ""

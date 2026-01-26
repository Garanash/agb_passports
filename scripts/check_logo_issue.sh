#!/bin/bash

# Скрипт для проверки проблемы с логотипом

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка проблемы с логотипом${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📁 Проверка наличия logo.png на сервере:${NC}"
ssh_exec "ls -lh $SERVER_PATH/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "❌ Файл не найден"

echo ""
echo -e "${YELLOW}📁 Проверка logo.png в контейнере backend:${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "❌ Файл не найден в контейнере"

echo ""
echo -e "${YELLOW}🧪 Тест функции create_logo_image() в контейнере:${NC}"
ssh_exec "docker exec agb_backend python3 -c \"
import sys
sys.path.insert(0, '/app')
from backend.utils.pdf_generator import create_logo_image
logo_path = create_logo_image()
print(f'Найденный путь: {logo_path}')
import os
if logo_path and os.path.exists(logo_path):
    size = os.path.getsize(logo_path)
    print(f'✅ Файл существует, размер: {size} байт')
else:
    print('❌ Файл не найден')
\" 2>&1" 2>&1 | grep -v "Warning"

echo ""
echo -e "${YELLOW}📋 Проверка кода pdf_generator.py (функция create_logo_image):${NC}"
ssh_exec "docker exec agb_backend grep -A 30 'def create_logo_image' /app/backend/utils/pdf_generator.py 2>&1" 2>&1 | head -35 | grep -v "Warning"

echo ""
echo -e "${YELLOW}📋 Проверка использования логотипа в generate_bulk_passports_pdf:${NC}"
ssh_exec "docker exec agb_backend grep -A 10 'logo_path\|create_logo_image' /app/backend/utils/pdf_generator.py | head -20 2>&1" 2>&1 | grep -v "Warning"

echo ""
echo -e "${YELLOW}📋 Проверка использования логотипа в sticker_template_generator:${NC}"
ssh_exec "docker exec agb_backend grep -A 10 'logo_path\|create_logo_image' /app/backend/utils/sticker_template_generator.py | head -30 2>&1" 2>&1 | grep -v "Warning"

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

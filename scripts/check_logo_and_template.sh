#!/bin/bash

# Проверка логотипа и шаблона наклеек

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка логотипа и шаблона наклеек${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📁 Проверка наличия logo.png:${NC}"
ssh_exec "ls -lh $SERVER_PATH/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "❌ Файл не найден на сервере"

echo ""
echo -e "${YELLOW}📁 Проверка logo.png в контейнере backend:${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "❌ Файл не найден в контейнере"

echo ""
echo -e "${YELLOW}🧪 Тест функции create_logo_image():${NC}"
LOGO_TEST=$(ssh_exec "docker exec agb_backend python3 -c \"
import sys
sys.path.insert(0, '/app')
from backend.utils.pdf_generator import create_logo_image
logo_path = create_logo_image()
print(logo_path)
import os
if logo_path and os.path.exists(logo_path):
    size = os.path.getsize(logo_path)
    print(f'Размер: {size} байт')
else:
    print('Файл не найден')
\" 2>&1" 2>&1 | grep -v "Warning")
echo "$LOGO_TEST"

echo ""
echo -e "${YELLOW}📁 Проверка шаблона наклеек:${NC}"
ssh_exec "ls -lh $SERVER_PATH/backend/utils/templates/sticker_template.docx 2>&1" 2>&1 | grep -v "Warning" || echo "❌ Шаблон не найден на сервере"

echo ""
echo -e "${YELLOW}📁 Проверка шаблона в контейнере:${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/templates/sticker_template.docx 2>&1" 2>&1 | grep -v "Warning" || echo "❌ Шаблон не найден в контейнере"

echo ""
echo -e "${YELLOW}🔍 Проверка использования штрихкодов в коде:${NC}"
ssh_exec "docker exec agb_backend grep -n 'stock_code\|serial_number_code' /app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" | head -5

echo ""
echo -e "${YELLOW}🔍 Проверка функции generate_barcode_image:${NC}"
ssh_exec "docker exec agb_backend grep -n 'def generate_barcode_image' /app/backend/utils/barcode_generator.py 2>&1" 2>&1 | grep -v "Warning" || echo "❌ Функция не найдена"

echo ""
echo -e "${YELLOW}📋 Проверка использования логотипа в pdf_generator:${NC}"
ssh_exec "docker exec agb_backend grep -n 'create_logo_image\|logo' /app/backend/utils/pdf_generator.py | head -10 2>&1" 2>&1 | grep -v "Warning"

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

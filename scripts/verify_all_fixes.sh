#!/bin/bash

# Финальная проверка всех исправлений

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}✅ Финальная проверка всех исправлений${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📁 Проверка файлов:${NC}"
echo -e "${YELLOW}1. Логотип:${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" | head -2

echo ""
echo -e "${YELLOW}2. Шаблон наклеек:${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/templates/sticker_template.docx 2>&1" 2>&1 | grep -v "Warning" | head -2

echo ""
echo -e "${YELLOW}3. Генератор штрихкодов:${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/barcode_generator.py 2>&1" 2>&1 | grep -v "Warning" | head -2

echo ""
echo -e "${YELLOW}🧪 Тест функции create_logo_image():${NC}"
LOGO_TEST=$(ssh_exec "docker exec agb_backend python3 -c \"
import sys
sys.path.insert(0, '/app')
from backend.utils.pdf_generator import create_logo_image
logo_path = create_logo_image()
print(f'Путь: {logo_path}')
import os
if logo_path and os.path.exists(logo_path):
    size = os.path.getsize(logo_path)
    print(f'Размер: {size} байт')
    if '/backend/utils/templates' in logo_path:
        print('✅ Путь правильный')
    else:
        print('⚠️ Путь не оптимальный')
\" 2>&1" 2>&1 | grep -v "Warning")
echo "$LOGO_TEST"

echo ""
echo -e "${YELLOW}🧪 Тест генерации штрихкода:${NC}"
BARCODE_TEST=$(ssh_exec "docker exec agb_backend python3 -c \"
import sys
sys.path.insert(0, '/app')
from backend.utils.barcode_generator import generate_barcode_image
import os
barcode_path = generate_barcode_image('TEST123', width_mm=35, height_mm=6)
if barcode_path and os.path.exists(barcode_path):
    size = os.path.getsize(barcode_path)
    print(f'✅ Штрихкод создан: {size} байт')
    os.unlink(barcode_path)
else:
    print('❌ Штрихкод не создан')
\" 2>&1" 2>&1 | grep -v "Warning")
echo "$BARCODE_TEST"

echo ""
echo -e "${YELLOW}🔍 Проверка использования штрихкодов в коде:${NC}"
BARCODE_USAGE=$(ssh_exec "docker exec agb_backend grep -n 'stock_code\|serial_number_code\|generate_barcode_image' /app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" | head -5)
if [ ! -z "$BARCODE_USAGE" ]; then
    echo -e "${GREEN}✅ Штрихкоды используются в коде${NC}"
    echo "$BARCODE_USAGE"
else
    echo -e "${RED}❌ Штрихкоды не используются${NC}"
fi

echo ""
echo -e "${YELLOW}🔍 Проверка использования логотипа в pdf_generator:${NC}"
LOGO_USAGE=$(ssh_exec "docker exec agb_backend grep -n 'create_logo_image\|logo_img\|logo_path' /app/backend/utils/pdf_generator.py | head -5 2>&1" 2>&1 | grep -v "Warning")
if [ ! -z "$LOGO_USAGE" ]; then
    echo -e "${GREEN}✅ Логотип используется в коде${NC}"
    echo "$LOGO_USAGE" | head -3
else
    echo -e "${RED}❌ Логотип не используется${NC}"
fi

echo ""
echo -e "${YELLOW}📊 Статус backend:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps backend 2>&1" 2>&1 | grep -E "NAME|agb_backend" || true

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

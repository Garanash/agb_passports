#!/bin/bash

# Скрипт для проверки реализации штрихкодов

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}✅ Проверка реализации штрихкодов${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📦 Проверка установленных библиотек:${NC}"
ssh_exec "docker exec agb_backend pip list | grep -E 'barcode|Pillow' 2>&1" 2>&1 | grep -v "Warning"

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
echo -e "${YELLOW}📋 Проверка наличия файлов:${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/barcode_generator.py /app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" | head -3

echo ""
echo -e "${YELLOW}🔍 Проверка использования штрихкодов в коде:${NC}"
ssh_exec "docker exec agb_backend grep -n 'stock_code\|serial_number_code' /app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" | head -5

echo ""
echo -e "${YELLOW}📊 Статус backend:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps backend 2>&1" 2>&1 | grep -E "NAME|agb_backend" || true

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""
echo -e "${BLUE}💡 Теперь в шаблоне наклеек можно использовать:${NC}"
echo -e "${BLUE}   - {{ stock_code }} - штрихкод кода номенклатуры (article или code_1c)${NC}"
echo -e "${BLUE}   - {{ serial_number_code }} - штрихкод серийного номера (passport_number)${NC}"
echo -e "${BLUE}   Размер штрихкодов: 35x6 мм (компактные)${NC}"
echo ""

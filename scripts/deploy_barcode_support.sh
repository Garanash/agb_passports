#!/bin/bash

# Скрипт для развертывания поддержки штрихкодов

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Развертывание поддержки штрихкодов${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📦 Копирование обновленных файлов...${NC}"
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no backend/utils/sticker_template_generator.py "$SERVER:$SERVER_PATH/backend/utils/sticker_template_generator.py" 2>&1 | grep -v "Warning" || true
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no backend/requirements.txt "$SERVER:$SERVER_PATH/backend/requirements.txt" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Файлы скопированы${NC}"

echo ""
echo -e "${YELLOW}📦 Установка новых зависимостей в контейнере...${NC}"
ssh_exec "docker exec agb_backend pip install python-barcode==0.15.1 Pillow==10.1.0 2>&1" 2>&1 | tail -10 | grep -v "Warning"

echo ""
echo -e "${YELLOW}📦 Копирование файлов в контейнер backend...${NC}"
ssh_exec "docker cp $SERVER_PATH/backend/utils/sticker_template_generator.py agb_backend:/app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Файлы скопированы в контейнер${NC}"

echo ""
echo -e "${YELLOW}🧪 Тест импорта библиотек штрихкодов...${NC}"
IMPORT_TEST=$(ssh_exec "docker exec agb_backend python3 -c \"
try:
    import barcode
    from barcode.writer import ImageWriter
    from PIL import Image
    print('✅ Все библиотеки импортированы успешно')
    print(f'   python-barcode версия: {barcode.__version__}')
except ImportError as e:
    print(f'❌ Ошибка импорта: {e}')
\" 2>&1" 2>&1 | grep -v "Warning")
echo "$IMPORT_TEST"

echo ""
echo -e "${YELLOW}🧪 Тест генерации штрихкода...${NC}"
BARCODE_TEST=$(ssh_exec "docker exec agb_backend python3 -c \"
import sys
sys.path.insert(0, '/app')
from backend.utils.sticker_template_generator import generate_barcode_image
import os

barcode_path = generate_barcode_image('TEST123', width_mm=35, height_mm=6)
if barcode_path and os.path.exists(barcode_path):
    size = os.path.getsize(barcode_path)
    print(f'✅ Штрихкод создан успешно: {barcode_path} (размер: {size} байт)')
    os.unlink(barcode_path)
else:
    print('❌ Штрихкод не создан')
\" 2>&1" 2>&1 | grep -v "Warning")
echo "$BARCODE_TEST"

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (5 секунд)...${NC}"
sleep 5

echo ""
echo -e "${YELLOW}📋 Статус backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps backend 2>&1" 2>&1 | grep -E "NAME|agb_backend" || true

echo ""
echo -e "${GREEN}✅ Развертывание завершено!${NC}"
echo ""
echo -e "${BLUE}💡 Теперь в шаблоне наклеек можно использовать:${NC}"
echo -e "${BLUE}   - {{ stock_code }} - штрихкод кода номенклатуры${NC}"
echo -e "${BLUE}   - {{ serial_number_code }} - штрихкод серийного номера${NC}"
echo ""

#!/bin/bash

# Скрипт для исправления всех проблем

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔧 Исправление всех проблем${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📦 Копирование всех необходимых файлов...${NC}"

# Копируем файлы
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no backend/utils/pdf_generator.py "$SERVER:$SERVER_PATH/backend/utils/pdf_generator.py" 2>&1 | grep -v "Warning" || true
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no backend/utils/sticker_template_generator.py "$SERVER:$SERVER_PATH/backend/utils/sticker_template_generator.py" 2>&1 | grep -v "Warning" || true
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no backend/utils/barcode_generator.py "$SERVER:$SERVER_PATH/backend/utils/barcode_generator.py" 2>&1 | grep -v "Warning" || true

# Копируем логотип если нужно
if [ -f "backend/utils/templates/logo.png" ]; then
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no backend/utils/templates/logo.png "$SERVER:$SERVER_PATH/backend/utils/templates/logo.png" 2>&1 | grep -v "Warning" || true
    echo -e "${GREEN}✅ Логотип скопирован${NC}"
fi

# Копируем шаблон наклеек если нужно
if [ -f "backend/utils/templates/sticker_template.docx" ]; then
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no backend/utils/templates/sticker_template.docx "$SERVER:$SERVER_PATH/backend/utils/templates/sticker_template.docx" 2>&1 | grep -v "Warning" || true
    echo -e "${GREEN}✅ Шаблон наклеек скопирован${NC}"
fi

echo -e "${GREEN}✅ Файлы скопированы${NC}"

echo ""
echo -e "${YELLOW}📦 Копирование файлов в контейнер backend...${NC}"
ssh_exec "docker cp $SERVER_PATH/backend/utils/pdf_generator.py agb_backend:/app/backend/utils/pdf_generator.py 2>&1" 2>&1 | grep -v "Warning" || true
ssh_exec "docker cp $SERVER_PATH/backend/utils/sticker_template_generator.py agb_backend:/app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" || true
ssh_exec "docker cp $SERVER_PATH/backend/utils/barcode_generator.py agb_backend:/app/backend/utils/barcode_generator.py 2>&1" 2>&1 | grep -v "Warning" || true
ssh_exec "docker cp $SERVER_PATH/backend/utils/templates/logo.png agb_backend:/app/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || true
ssh_exec "docker cp $SERVER_PATH/backend/utils/templates/sticker_template.docx agb_backend:/app/backend/utils/templates/sticker_template.docx 2>&1" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Файлы скопированы в контейнер${NC}"

echo ""
echo -e "${YELLOW}🧪 Проверка наличия файлов в контейнере:${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/barcode_generator.py /app/backend/utils/templates/logo.png /app/backend/utils/templates/sticker_template.docx 2>&1" 2>&1 | grep -v "Warning" | head -5

echo ""
echo -e "${YELLOW}🧪 Тест функции create_logo_image():${NC}"
LOGO_TEST=$(ssh_exec "docker exec agb_backend python3 -c \"
import sys
sys.path.insert(0, '/app')
from backend.utils.pdf_generator import create_logo_image
logo_path = create_logo_image()
print(f'Найденный путь: {logo_path}')
import os
if logo_path and os.path.exists(logo_path):
    size = os.path.getsize(logo_path)
    print(f'✅ Файл существует, размер: {size} байт')
    if '/backend/utils/templates' in logo_path:
        print('✅ Путь правильный')
    else:
        print('⚠️ Путь не оптимальный')
else:
    print('❌ Файл не найден')
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
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (5 секунд)...${NC}"
sleep 5

echo ""
echo -e "${YELLOW}🔑 Исправление пароля БД...${NC}"
ssh_exec "docker exec -i agb_postgres psql -U postgres <<EOF
ALTER ROLE postgres WITH PASSWORD 'password';
\q
EOF
" > /dev/null 2>&1

echo ""
echo -e "${YELLOW}📋 Статус backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps backend 2>&1" 2>&1 | grep -E "NAME|agb_backend" || true

echo ""
echo -e "${YELLOW}📋 Последние логи backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 10 2>&1" 2>&1 | tail -15 | grep -v "Warning"

echo ""
echo -e "${GREEN}✅ Исправление завершено!${NC}"
echo ""

#!/bin/bash

# Скрипт для прямого тестирования логотипа в контейнере

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧪 Прямое тестирование логотипа в контейнере${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🧪 Тест функции create_logo_image()...${NC}"
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
echo -e "${YELLOW}🧪 Тест импорта и использования логотипа в pdf_generator...${NC}"
ssh_exec "docker exec agb_backend python3 -c \"
import sys
sys.path.insert(0, '/app')
from backend.utils.pdf_generator import create_logo_image
from reportlab.lib.units import mm
from reportlab.platypus import Image
import os

logo_path = create_logo_image()
if logo_path and os.path.exists(logo_path):
    try:
        # Пробуем создать Image объект (как в коде)
        logo_img = Image(logo_path, width=18*mm, height=5.4*mm)
        print(f'✅ Логотип успешно загружен в Image объект')
        print(f'   Путь: {logo_path}')
        print(f'   Размер изображения: 18x5.4 мм')
    except Exception as e:
        print(f'❌ Ошибка при создании Image: {e}')
else:
    print('❌ Логотип не найден')
\" 2>&1" 2>&1 | grep -v "Warning"

echo ""
echo -e "${YELLOW}🧪 Тест использования логотипа в sticker_template_generator...${NC}"
ssh_exec "docker exec agb_backend python3 -c \"
import sys
import os
sys.path.insert(0, '/app')

# Проверяем логику поиска логотипа как в sticker_template_generator
current_dir = os.path.dirname('/app/backend/utils/sticker_template_generator.py')
docker_templates_path = '/app/backend/utils/templates/logo.png'

logo_path = None
if os.path.exists(docker_templates_path):
    file_size = os.path.getsize(docker_templates_path)
    if file_size > 0:
        logo_path = docker_templates_path
        print(f'✅ Логотип найден: {logo_path} (размер: {file_size} байт)')
    else:
        print(f'⚠️ Файл пустой: {docker_templates_path}')
else:
    print(f'❌ Файл не найден: {docker_templates_path}')

if logo_path:
    from docxtpl import InlineImage
    from docx import Document
    from docx.shared import Mm as DocxMm
    
    # Создаем временный документ для теста
    doc = Document()
    template = doc
    
    try:
        logo_img = InlineImage(template, logo_path, width=DocxMm(18), height=DocxMm(5.4))
        print(f'✅ Логотип успешно создан как InlineImage для docxtpl')
    except Exception as e:
        print(f'❌ Ошибка при создании InlineImage: {e}')
\" 2>&1" 2>&1 | grep -v "Warning"

echo ""
echo -e "${YELLOW}📋 Последние логи backend (20 строк)...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs backend --tail 20 2>&1" 2>&1 | tail -25 | grep -v "Warning"

echo ""
echo -e "${GREEN}✅ Тестирование завершено!${NC}"
echo ""

#!/bin/bash

# Скрипт для финальной проверки исправления логотипа

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}✅ Финальная проверка исправления логотипа${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📁 Проверка наличия logo.png:${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/templates/logo.png 2>&1" 2>&1 | grep -v "Warning" || echo "❌ Файл не найден"

echo ""
echo -e "${YELLOW}🧪 Тест функции create_logo_image():${NC}"
LOGO_TEST=$(ssh_exec "docker exec agb_backend python3 -c \"
import sys
sys.path.insert(0, '/app')
from backend.utils.pdf_generator import create_logo_image
logo_path = create_logo_image()
print(logo_path)
\" 2>&1" 2>&1 | grep -v "Warning" | tail -1)

if echo "$LOGO_TEST" | grep -q "/app/backend/utils/templates/logo.png"; then
    echo -e "${GREEN}✅ Функция правильно находит логотип: $LOGO_TEST${NC}"
else
    echo -e "${RED}❌ Функция возвращает неправильный путь: $LOGO_TEST${NC}"
fi

echo ""
echo -e "${YELLOW}📋 Проверка кода pdf_generator.py (приоритеты):${NC}"
ssh_exec "docker exec agb_backend grep -A 5 'ПРИОРИТЕТ 1' /app/backend/utils/pdf_generator.py 2>&1" 2>&1 | grep -v "Warning" | head -3

echo ""
echo -e "${YELLOW}📋 Проверка кода sticker_template_generator.py (приоритеты):${NC}"
ssh_exec "docker exec agb_backend grep -A 5 'ПРИОРИТЕТ 1' /app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" | head -3

echo ""
echo -e "${YELLOW}📊 Статус backend:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps backend 2>&1" 2>&1 | grep -E "NAME|agb_backend" || true

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""
echo -e "${BLUE}💡 Теперь логотип должен появляться на:${NC}"
echo -e "${BLUE}   - Паспортах (PDF)${NC}"
echo -e "${BLUE}   - Наклейках (DOCX и PDF)${NC}"
echo ""

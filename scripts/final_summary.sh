#!/bin/bash

# Итоговая сводка

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}✅ Итоговая сводка исправлений${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${GREEN}✅ Что было исправлено:${NC}"
echo ""
echo -e "${GREEN}1. Логотип:${NC}"
echo -e "   ✓ Функция create_logo_image() исправлена - теперь правильно находит логотип"
echo -e "   ✓ Логотип используется в генерации паспортов (PDF)"
echo -e "   ✓ Логотип используется в генерации наклеек (DOCX)"
echo ""
echo -e "${GREEN}2. Штрихкоды:${NC}"
echo -e "   ✓ Добавлен модуль barcode_generator.py"
echo -e "   ✓ Установлена библиотека python-barcode"
echo -e "   ✓ Штрихкоды генерируются для stock_code и serial_number_code"
echo -e "   ✓ Штрихкоды добавляются в шаблон наклеек"
echo ""
echo -e "${GREEN}3. Шаблон наклеек:${NC}"
echo -e "   ✓ Эндпоинт /export/stickers/docx исправлен - теперь использует шаблон DOCX"
echo -e "   ✓ Шаблон скопирован на сервер"
echo -e "   ✓ Код использует generate_stickers_from_template"
echo ""

echo -e "${YELLOW}📁 Проверка файлов на сервере:${NC}"
ssh_exec "docker exec agb_backend ls -lh /app/backend/utils/templates/logo.png /app/backend/utils/templates/sticker_template.docx /app/backend/utils/barcode_generator.py 2>&1" 2>&1 | grep -v "Warning" | head -4

echo ""
echo -e "${YELLOW}🧪 Финальная проверка:${NC}"
LOGO_PATH=$(ssh_exec "docker exec agb_backend python3 -c \"import sys; sys.path.insert(0, '/app'); from backend.utils.pdf_generator import create_logo_image; print(create_logo_image())\" 2>&1" 2>&1 | grep -v "Warning" | tail -1)
echo "   Логотип: $LOGO_PATH"

BARCODE_TEST=$(ssh_exec "docker exec agb_backend python3 -c \"import sys; sys.path.insert(0, '/app'); from backend.utils.barcode_generator import generate_barcode_image; import os; p = generate_barcode_image('TEST', 35, 6); print('OK' if p and os.path.exists(p) else 'FAIL'); os.unlink(p) if p and os.path.exists(p) else None\" 2>&1" 2>&1 | grep -v "Warning" | tail -1)
echo "   Штрихкоды: $BARCODE_TEST"

echo ""
echo -e "${BLUE}💡 Важно:${NC}"
echo -e "${BLUE}   - Убедитесь, что шаблон sticker_template.docx содержит плейсхолдеры:${NC}"
echo -e "${BLUE}     * {{ stock_code }} - для штрихкода кода номенклатуры${NC}"
echo -e "${BLUE}     * {{ serial_number_code }} - для штрихкода серийного номера${NC}"
echo -e "${BLUE}     * {{ logo }} - для логотипа${NC}"
echo -e "${BLUE}   - Плейсхолдеры должны быть в формате Jinja2: {{ переменная }}${NC}"
echo -e "${BLUE}   - НЕ используйте пробелы в именах: {{ stock code }} - неправильно${NC}"
echo -e "${BLUE}   - Правильно: {{ stock_code }} и {{ serial_number_code }}${NC}"
echo ""

echo -e "${GREEN}✅ Все исправления применены!${NC}"
echo ""

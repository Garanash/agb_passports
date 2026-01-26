#!/bin/bash

# Скрипт для обновления кода логотипа в контейнере

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📤 Обновление кода логотипа${NC}"
echo ""

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📤 Копирование файла на сервер...${NC}"
scp_copy "$LOCAL_PATH/backend/utils/pdf_generator.py" "$SERVER:/tmp/pdf_generator.py"

echo ""
echo -e "${YELLOW}📋 Копирование файла в контейнер...${NC}"
ssh_exec "docker cp /tmp/pdf_generator.py agb_backend:/app/backend/utils/pdf_generator.py 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔍 Проверка обновленного кода...${NC}"
ssh_exec "docker exec agb_backend grep -A 5 'ПРИОРИТЕТ 1' /app/backend/utils/pdf_generator.py 2>&1" 2>&1 | head -10

echo ""
echo -e "${YELLOW}🔄 Перезапуск backend...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose restart backend 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}⏳ Ожидание запуска backend (8 секунд)...${NC}"
sleep 8

echo ""
echo -e "${YELLOW}🧪 Тест функции create_logo_image...${NC}"
ssh_exec "docker exec agb_backend python3 -c \"
import sys
sys.path.insert(0, '/app')
from backend.utils.pdf_generator import create_logo_image
logo = create_logo_image()
print(f'✅ Логотип найден: {logo}')
\" 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${GREEN}✅ Обновление завершено!${NC}"
echo ""

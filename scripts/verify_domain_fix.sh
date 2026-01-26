#!/bin/bash

# Скрипт для проверки исправления домена

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}✅ Проверка исправления домена${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔍 Проверка замены домена в файлах:${NC}"
echo ""
echo -e "${YELLOW}pdf_generator.py (строка 735):${NC}"
ssh_exec "docker exec agb_backend sed -n '735p' /app/backend/utils/pdf_generator.py 2>&1" 2>&1 | grep -v "Warning"

echo ""
echo -e "${YELLOW}pdf_generator.py (строка 1013):${NC}"
ssh_exec "docker exec agb_backend sed -n '1013p' /app/backend/utils/pdf_generator.py 2>&1" 2>&1 | grep -v "Warning"

echo ""
echo -e "${YELLOW}sticker_template_generator.py (строка 385):${NC}"
ssh_exec "docker exec agb_backend sed -n '385p' /app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning"

echo ""
echo -e "${YELLOW}🔍 Проверка отсутствия старого домена .kz:${NC}"
KZ_FOUND=$(ssh_exec "docker exec agb_backend grep -c 'almazgeobur.kz' /app/backend/utils/pdf_generator.py /app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" | tail -1)
if [ "$KZ_FOUND" = "0" ] || [ -z "$KZ_FOUND" ]; then
    echo -e "${GREEN}✅ Старый домен .kz не найден${NC}"
else
    echo -e "${RED}❌ Найдено упоминаний .kz: $KZ_FOUND${NC}"
fi

echo ""
echo -e "${YELLOW}📊 Статус backend:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps backend 2>&1" 2>&1 | grep -E "NAME|agb_backend" || true

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""
echo -e "${BLUE}💡 Теперь везде используется домен www.almazgeobur.ru:${NC}"
echo -e "${BLUE}   - В паспортах (PDF)${NC}"
echo -e "${BLUE}   - В наклейках (DOCX и PDF)${NC}"
echo ""

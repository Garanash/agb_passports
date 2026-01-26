#!/bin/bash

# Скрипт для развертывания исправления домена

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Развертывание исправления домена (kz -> ru)${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}📦 Копирование исправленных файлов...${NC}"
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no backend/utils/pdf_generator.py "$SERVER:$SERVER_PATH/backend/utils/pdf_generator.py" 2>&1 | grep -v "Warning" || true
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no backend/utils/sticker_template_generator.py "$SERVER:$SERVER_PATH/backend/utils/sticker_template_generator.py" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Файлы скопированы${NC}"

echo ""
echo -e "${YELLOW}📦 Копирование файлов в контейнер backend...${NC}"
ssh_exec "docker cp $SERVER_PATH/backend/utils/pdf_generator.py agb_backend:/app/backend/utils/pdf_generator.py 2>&1" 2>&1 | grep -v "Warning" || true
ssh_exec "docker cp $SERVER_PATH/backend/utils/sticker_template_generator.py agb_backend:/app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Файлы скопированы в контейнер${NC}"

echo ""
echo -e "${YELLOW}🧪 Проверка замены домена в файлах...${NC}"
KZ_COUNT=$(ssh_exec "docker exec agb_backend grep -c 'almazgeobur.kz' /app/backend/utils/pdf_generator.py /app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" | awk '{sum+=$1} END {print sum}' || echo "0")
RU_COUNT=$(ssh_exec "docker exec agb_backend grep -c 'almazgeobur.ru' /app/backend/utils/pdf_generator.py /app/backend/utils/sticker_template_generator.py 2>&1" 2>&1 | grep -v "Warning" | awk '{sum+=$1} END {print sum}' || echo "0")

if [ "$KZ_COUNT" = "0" ]; then
    echo -e "${GREEN}✅ Домен .kz не найден в файлах${NC}"
else
    echo -e "${YELLOW}⚠️ Найдено упоминаний .kz: $KZ_COUNT${NC}"
fi

if [ "$RU_COUNT" -gt "0" ]; then
    echo -e "${GREEN}✅ Найдено упоминаний .ru: $RU_COUNT${NC}"
else
    echo -e "${RED}❌ Домен .ru не найден${NC}"
fi

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
echo -e "${BLUE}💡 Теперь везде используется домен www.almazgeobur.ru${NC}"
echo ""

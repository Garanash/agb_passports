#!/bin/bash

# Быстрая проверка статуса сервера

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 Статус сервера AGB Passports${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

# 1. Статус контейнеров
echo -e "${YELLOW}📦 Контейнеры:${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps" 2>&1 | grep -v "Warning" | grep -E "(NAME|agb_)" || ssh_exec "cd $SERVER_PATH && docker-compose ps" 2>&1 | grep -v "Warning" | grep -E "(NAME|agb_)" || true
echo ""

# 2. Проверка логотипа
echo -e "${YELLOW}🖼️  Логотип:${NC}"
LOGO_CHECK=$(ssh_exec "test -f $SERVER_PATH/backend/utils/templates/logo.png && echo 'OK' || echo 'FAIL'" 2>&1 | grep -v "Warning" | tail -1)
if [ "$LOGO_CHECK" = "OK" ]; then
    SIZE=$(ssh_exec "ls -lh $SERVER_PATH/backend/utils/templates/logo.png 2>/dev/null | awk '{print \$5}'" 2>&1 | grep -v "Warning" | tail -1 || echo "unknown")
    echo -e "${GREEN}✅ Найден (размер: $SIZE)${NC}"
else
    echo -e "${RED}❌ Не найден${NC}"
fi
echo ""

# 3. Проверка шаблонов
echo -e "${YELLOW}📄 Шаблоны:${NC}"
TEMPLATES=("sticker_template.xlsx" "sticker_template.docx" "passport_template.docx")
for template in "${TEMPLATES[@]}"; do
    CHECK=$(ssh_exec "test -f $SERVER_PATH/backend/utils/templates/$template && echo 'OK' || echo 'FAIL'" 2>&1 | grep -v "Warning" | tail -1)
    if [ "$CHECK" = "OK" ]; then
        echo -e "${GREEN}✅ $template${NC}"
    else
        echo -e "${RED}❌ $template${NC}"
    fi
done
echo ""

# 4. Проверка базы данных
echo -e "${YELLOW}🗄️  База данных:${NC}"
if ssh_exec "docker exec agb_postgres pg_isready -U postgres" 2>&1 | grep -v "Warning" | grep -q "accepting connections"; then
    COUNT=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c 'SELECT COUNT(*) FROM passports;'" 2>&1 | grep -v "Warning" | tr -d ' ' || echo "0")
    echo -e "${GREEN}✅ PostgreSQL готов (паспортов: $COUNT)${NC}"
else
    echo -e "${RED}❌ PostgreSQL недоступен${NC}"
fi
echo ""

# 5. Проверка бекапов
echo -e "${YELLOW}💾 Бекапы:${NC}"
BACKUP_COUNT=$(ssh_exec "ls -1 $SERVER_PATH/backups/full_backup_*.tar.gz 2>/dev/null | wc -l" 2>&1 | grep -v "Warning" | tr -d ' ' || echo "0")
if [ "$BACKUP_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Найдено бекапов: $BACKUP_COUNT${NC}"
else
    echo -e "${YELLOW}⚠️  Бекапы не найдены${NC}"
fi
echo ""

# 6. Проверка доступности
echo -e "${YELLOW}🌍 Доступность:${NC}"
EXTERNAL_IP="185.247.17.188"
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://$EXTERNAL_IP" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Приложение доступно: http://$EXTERNAL_IP${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP код: $HTTP_CODE${NC}"
fi
echo ""

# 7. Последние ошибки backend
echo -e "${YELLOW}📋 Последние ошибки backend:${NC}"
ERRORS=$(ssh_exec "cd $SERVER_PATH && docker compose logs --tail=5 backend 2>&1 | grep -i error || echo 'Ошибок не найдено'" 2>&1 | grep -v "Warning" | tail -3)
if echo "$ERRORS" | grep -qi "error"; then
    echo -e "${RED}$ERRORS${NC}"
else
    echo -e "${GREEN}$ERRORS${NC}"
fi

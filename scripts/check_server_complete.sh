#!/bin/bash

# Полная проверка сервера AGB Passports

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

echo -e "${BLUE}🔍 Полная проверка сервера AGB Passports${NC}"
echo ""

# Проверяем наличие sshpass
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}❌ sshpass не установлен. Установите: brew install hudochenkov/sshpass/sshpass${NC}"
    exit 1
fi

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

# Функция для проверки HTTP
check_http() {
    local url=$1
    local name=$2
    local response=$(ssh_exec "curl -s -o /dev/null -w '%{http_code}' $url" 2>&1 | grep -v "Warning" || echo "000")
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✅ $name: OK (HTTP $response)${NC}"
        return 0
    else
        echo -e "${RED}❌ $name: FAILED (HTTP $response)${NC}"
        return 1
    fi
}

# 1. Проверка статуса контейнеров
echo -e "${YELLOW}📦 Проверка контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps" 2>&1 | grep -v "Warning" || ssh_exec "cd $SERVER_PATH && docker-compose ps" 2>&1 | grep -v "Warning" || true
echo ""

# 2. Проверка API
echo -e "${YELLOW}🌐 Проверка API...${NC}"
check_http "http://localhost:8000/api/v1/health" "Backend Health"
check_http "http://localhost:8000/api/v1/auth/login" "Backend API"
check_http "http://localhost:3000" "Frontend"
check_http "http://localhost" "Nginx"
echo ""

# 3. Проверка логотипа
echo -e "${YELLOW}🖼️  Проверка логотипа...${NC}"
LOGO_PATHS=(
    "/root/agb_passports/backend/utils/templates/logo.png"
    "/app/backend/utils/templates/logo.png"
    "/app/templates/logo.png"
)

LOGO_FOUND=false
for path in "${LOGO_PATHS[@]}"; do
    if ssh_exec "test -f $path" 2>&1 | grep -v "Warning" > /dev/null 2>&1; then
        SIZE=$(ssh_exec "ls -lh $path 2>/dev/null | awk '{print \$5}'" 2>&1 | grep -v "Warning" || echo "unknown")
        echo -e "${GREEN}✅ Логотип найден: $path (размер: $SIZE)${NC}"
        LOGO_FOUND=true
        break
    fi
done

if [ "$LOGO_FOUND" = false ]; then
    echo -e "${RED}❌ Логотип не найден ни по одному из путей!${NC}"
fi
echo ""

# 4. Проверка шаблонов
echo -e "${YELLOW}📄 Проверка шаблонов...${NC}"
TEMPLATES=(
    "sticker_template.xlsx"
    "sticker_template.docx"
    "passport_template.docx"
)

for template in "${TEMPLATES[@]}"; do
    if ssh_exec "test -f $SERVER_PATH/backend/utils/templates/$template" 2>&1 | grep -v "Warning" > /dev/null 2>&1; then
        SIZE=$(ssh_exec "ls -lh $SERVER_PATH/backend/utils/templates/$template 2>/dev/null | awk '{print \$5}'" 2>&1 | grep -v "Warning" || echo "unknown")
        echo -e "${GREEN}✅ $template найден (размер: $SIZE)${NC}"
    else
        echo -e "${RED}❌ $template не найден!${NC}"
    fi
done
echo ""

# 5. Проверка базы данных
echo -e "${YELLOW}🗄️  Проверка базы данных...${NC}"
if ssh_exec "docker exec agb_postgres pg_isready -U postgres" 2>&1 | grep -v "Warning" | grep -q "accepting connections"; then
    echo -e "${GREEN}✅ PostgreSQL готов к подключениям${NC}"
    
    # Проверяем количество записей
    COUNT=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c 'SELECT COUNT(*) FROM passports;'" 2>&1 | grep -v "Warning" | tr -d ' ' || echo "0")
    echo -e "${BLUE}   Паспортов в базе: $COUNT${NC}"
else
    echo -e "${RED}❌ PostgreSQL недоступен!${NC}"
fi
echo ""

# 6. Проверка бекапов
echo -e "${YELLOW}💾 Проверка бекапов...${NC}"
BACKUP_COUNT=$(ssh_exec "ls -1 $SERVER_PATH/backups/full_backup_*.tar.gz 2>/dev/null | wc -l" 2>&1 | grep -v "Warning" | tr -d ' ' || echo "0")
if [ "$BACKUP_COUNT" -gt 0 ]; then
    BACKUP_SIZE=$(ssh_exec "du -sh $SERVER_PATH/backups 2>/dev/null | awk '{print \$1}'" 2>&1 | grep -v "Warning" || echo "unknown")
    LAST_BACKUP=$(ssh_exec "ls -t $SERVER_PATH/backups/full_backup_*.tar.gz 2>/dev/null | head -1" 2>&1 | grep -v "Warning" | xargs basename 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ Найдено бекапов: $BACKUP_COUNT${NC}"
    echo -e "${BLUE}   Общий размер: $BACKUP_SIZE${NC}"
    echo -e "${BLUE}   Последний бекап: $LAST_BACKUP${NC}"
else
    echo -e "${YELLOW}⚠️  Бекапы не найдены${NC}"
fi
echo ""

# 7. Проверка cron для бекапа
echo -e "${YELLOW}⏰ Проверка расписания бекапа...${NC}"
if ssh_exec "crontab -l 2>/dev/null | grep -q 'full_backup.sh'" 2>&1 | grep -v "Warning" > /dev/null 2>&1; then
    CRON_JOB=$(ssh_exec "crontab -l 2>/dev/null | grep 'full_backup.sh'" 2>&1 | grep -v "Warning" || echo "")
    echo -e "${GREEN}✅ Автоматический бекап настроен:${NC}"
    echo -e "${BLUE}   $CRON_JOB${NC}"
else
    echo -e "${YELLOW}⚠️  Автоматический бекап не настроен${NC}"
fi
echo ""

# 8. Проверка логов на ошибки
echo -e "${YELLOW}📋 Проверка последних ошибок в логах...${NC}"
echo -e "${BLUE}Backend (последние 10 строк):${NC}"
ssh_exec "cd $SERVER_PATH && docker compose logs --tail=10 backend 2>&1 | grep -i error || echo 'Ошибок не найдено'" 2>&1 | grep -v "Warning" || ssh_exec "cd $SERVER_PATH && docker-compose logs --tail=10 backend 2>&1 | grep -i error || echo 'Ошибок не найдено'" 2>&1 | grep -v "Warning" || true
echo ""

# 9. Проверка дискового пространства
echo -e "${YELLOW}💿 Проверка дискового пространства...${NC}"
ssh_exec "df -h / | tail -1" 2>&1 | grep -v "Warning" || true
echo ""

# 10. Проверка доступности приложения извне
echo -e "${YELLOW}🌍 Проверка доступности приложения извне...${NC}"
EXTERNAL_IP="185.247.17.188"
if curl -s -o /dev/null -w '%{http_code}' "http://$EXTERNAL_IP" | grep -q "200"; then
    echo -e "${GREEN}✅ Приложение доступно по адресу: http://$EXTERNAL_IP${NC}"
else
    echo -e "${YELLOW}⚠️  Приложение может быть недоступно извне${NC}"
fi
echo ""

echo -e "${GREEN}✅ Проверка завершена!${NC}"

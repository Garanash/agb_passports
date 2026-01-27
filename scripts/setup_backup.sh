#!/bin/bash

# Настройка автоматического бекапа для AGB Passports
# Бекапит: база данных, шаблоны, логотип

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}💾 Настройка автоматического бекапа${NC}"
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

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

echo -e "${YELLOW}📦 Шаг 1: Создание директорий для бекапов на сервере...${NC}"
ssh_exec "mkdir -p $SERVER_PATH/backups/db" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/backups/templates" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/backups/logo" 2>&1 | grep -v "Warning" || true

echo -e "${YELLOW}📤 Шаг 2: Копирование скриптов бекапа на сервер...${NC}"
scp_copy "$LOCAL_PATH/scripts/backup_db.sh" "$SERVER:$SERVER_PATH/scripts/"
scp_copy "$LOCAL_PATH/scripts/backup.sh" "$SERVER:$SERVER_PATH/scripts/"

# Создаем улучшенный скрипт полного бекапа
cat > /tmp/full_backup.sh << 'EOF'
#!/bin/bash

# Полный бекап AGB Passports
# Бекапит: база данных, шаблоны, логотип

set -e

BACKUP_BASE="/root/agb_passports/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE/full_${TIMESTAMP}"

# Создаем директорию для бекапа
mkdir -p "$BACKUP_DIR/db"
mkdir -p "$BACKUP_DIR/templates"
mkdir -p "$BACKUP_DIR/logo"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] 💾 Начинаем полный бекап..."

# 1. Бекап базы данных
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 📦 Бекап базы данных..."
cd /root/agb_passports
docker exec agb_postgres pg_dump -U postgres -d agb_passports > "$BACKUP_DIR/db/agb_passports_${TIMESTAMP}.sql"
gzip "$BACKUP_DIR/db/agb_passports_${TIMESTAMP}.sql"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ База данных забэкаплена"

# 2. Бекап шаблонов
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 📦 Бекап шаблонов..."
if [ -d "/root/agb_passports/backend/utils/templates" ]; then
    cp -r /root/agb_passports/backend/utils/templates/* "$BACKUP_DIR/templates/" 2>/dev/null || true
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ Шаблоны забэкаплены"
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️ Директория шаблонов не найдена"
fi

# 3. Бекап логотипа
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 📦 Бекап логотипа..."
if [ -f "/root/agb_passports/backend/utils/templates/logo.png" ]; then
    cp /root/agb_passports/backend/utils/templates/logo.png "$BACKUP_DIR/logo/logo_${TIMESTAMP}.png"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ Логотип забэкаплен"
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️ Логотип не найден"
fi

# Создаем архив
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 📦 Создаем архив..."
cd "$BACKUP_BASE"
tar -czf "full_backup_${TIMESTAMP}.tar.gz" "full_${TIMESTAMP}"
rm -rf "full_${TIMESTAMP}"

# Удаляем старые бекапы (оставляем последние 7)
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🗑️ Удаляем старые бекапы..."
ls -t full_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm -f

# Статистика
TOTAL_BACKUPS=$(ls -1 full_backup_*.tar.gz 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_BASE" 2>/dev/null | cut -f1 || echo "0")

echo ""
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 📊 Статистика бекапа:"
echo "   Всего бекапов: $TOTAL_BACKUPS"
echo "   Общий размер: $TOTAL_SIZE"
echo "   Последний бекап: full_backup_${TIMESTAMP}.tar.gz"
echo ""
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🎉 Полный бекап завершен!"
EOF

scp_copy "/tmp/full_backup.sh" "$SERVER:$SERVER_PATH/scripts/"
ssh_exec "chmod +x $SERVER_PATH/scripts/full_backup.sh" 2>&1 | grep -v "Warning" || true

# Настраиваем cron для автоматического бекапа (каждый день в 3:00)
echo -e "${YELLOW}⏰ Шаг 3: Настройка автоматического бекапа (cron)...${NC}"
ssh_exec "crontab -l 2>/dev/null | grep -v 'full_backup.sh' | crontab -" 2>&1 | grep -v "Warning" || true
ssh_exec "(crontab -l 2>/dev/null; echo '0 3 * * * /root/agb_passports/scripts/full_backup.sh >> /root/agb_passports/backups/backup.log 2>&1') | crontab -" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Автоматический бекап настроен!${NC}"
echo ""
echo -e "${BLUE}📋 Расписание бекапов:${NC}"
echo "   - Полный бекап: каждый день в 3:00"
echo "   - Хранится: последние 7 бекапов"
echo "   - Директория: /root/agb_passports/backups/"
echo ""
echo -e "${YELLOW}💡 Для ручного запуска бекапа:${NC}"
echo "   ssh root@185.247.17.188 'cd /root/agb_passports && bash scripts/full_backup.sh'"

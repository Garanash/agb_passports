#!/bin/bash

# Скрипт для автоматического резервного копирования базы данных AGB Passports
# Хранит только 5 последних бекапов

set -e

# Конфигурация
BACKUP_DIR="/root/agb_passports/backups"
DB_NAME="agb_passports"
DB_USER="postgres"
DB_PASSWORD="password"
CONTAINER_NAME="agb_postgres"
MAX_BACKUPS=5

# Создаем директорию для бэкапов
mkdir -p "$BACKUP_DIR"

# Генерируем имя файла бэкапа
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/agb_passports_${TIMESTAMP}.sql"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🗄️  Начинаем резервное копирование базы данных..."

# Проверяем, что контейнер запущен
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ Контейнер $CONTAINER_NAME не запущен!"
    exit 1
fi

# Проверяем доступность базы данных
if ! docker exec "$CONTAINER_NAME" pg_isready -U "$DB_USER" > /dev/null 2>&1; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ База данных недоступна!"
    exit 1
fi

# Создаем бэкап
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 📦 Создаем бэкап: $BACKUP_FILE"
docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_FILE"

# Проверяем, что бэкап создан
if [ ! -f "$BACKUP_FILE" ] || [ ! -s "$BACKUP_FILE" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ Ошибка создания бэкапа!"
    exit 1
fi

# Проверяем размер бэкапа
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ Бэкап создан успешно! Размер: $BACKUP_SIZE"

# Сжимаем бэкап
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🗜️  Сжимаем бэкап..."
gzip "$BACKUP_FILE"
BACKUP_FILE="${BACKUP_FILE}.gz"
COMPRESSED_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ Бэкап сжат! Размер: $COMPRESSED_SIZE"

# Удаляем старые бэкапы, оставляя только MAX_BACKUPS последних
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🗑️  Удаляем старые бэкапы, оставляя $MAX_BACKUPS последних..."
cd "$BACKUP_DIR"
ls -t agb_passports_*.sql.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -f

# Показываем статистику
TOTAL_BACKUPS=$(ls -1 agb_passports_*.sql.gz 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "0")

echo ""
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 📊 Статистика резервного копирования:"
echo "   Всего бэкапов: $TOTAL_BACKUPS"
echo "   Общий размер: $TOTAL_SIZE"
echo "   Последний бэкап: $(basename $BACKUP_FILE)"
echo ""
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 🎉 Резервное копирование завершено!"


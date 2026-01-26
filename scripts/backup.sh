#!/bin/bash

# Скрипт для резервного копирования базы данных AGB Passports

set -e

# Конфигурация
BACKUP_DIR="/backups"
DB_NAME="agb_passports"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

# Создаем директорию для бэкапов
mkdir -p "$BACKUP_DIR"

# Генерируем имя файла бэкапа
BACKUP_FILE="$BACKUP_DIR/agb_passports_$(date +%Y%m%d_%H%M%S).sql"

echo "🗄️  Начинаем резервное копирование базы данных..."

# Проверяем доступность базы данных
if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; then
    echo "❌ База данных недоступна!"
    exit 1
fi

# Создаем бэкап
echo "📦 Создаем бэкап: $BACKUP_FILE"
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_FILE"

# Проверяем размер бэкапа
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "✅ Бэкап создан успешно! Размер: $BACKUP_SIZE"

# Сжимаем бэкап
echo "🗜️  Сжимаем бэкап..."
gzip "$BACKUP_FILE"
BACKUP_FILE="${BACKUP_FILE}.gz"
COMPRESSED_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "✅ Бэкап сжат! Размер: $COMPRESSED_SIZE"

# Удаляем старые бэкапы
echo "🗑️  Удаляем бэкапы старше $RETENTION_DAYS дней..."
find "$BACKUP_DIR" -name "agb_passports_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete

# Показываем статистику
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -name "agb_passports_*.sql.gz" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

echo ""
echo "📊 Статистика резервного копирования:"
echo "   Всего бэкапов: $TOTAL_BACKUPS"
echo "   Общий размер: $TOTAL_SIZE"
echo "   Последний бэкап: $BACKUP_FILE"
echo ""

# Опционально: отправка бэкапа на удаленный сервер
if [ -n "$REMOTE_BACKUP_HOST" ] && [ -n "$REMOTE_BACKUP_PATH" ]; then
    echo "☁️  Отправляем бэкап на удаленный сервер..."
    scp "$BACKUP_FILE" "$REMOTE_BACKUP_HOST:$REMOTE_BACKUP_PATH/"
    echo "✅ Бэкап отправлен на удаленный сервер!"
fi

echo "🎉 Резервное копирование завершено!"

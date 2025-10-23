#!/bin/bash

# Скрипт инициализации базы данных из бекапа
# Использование: ./init_database.sh

set -e

echo "🚀 Инициализация базы данных AGB Passports..."

# Проверяем наличие бекапа
BACKUP_FILE="backup_clean_state_20251022_213032.sql"
if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Файл бекапа $BACKUP_FILE не найден!"
    exit 1
fi

echo "✅ Найден файл бекапа: $BACKUP_FILE"

# Проверяем переменные окружения
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "⚠️  POSTGRES_PASSWORD не установлен, используем значение по умолчанию"
    export POSTGRES_PASSWORD="agb_passports_2024"
fi

# Ждем запуска PostgreSQL
echo "⏳ Ожидание запуска PostgreSQL..."
until docker-compose -f docker-compose.production.yml exec postgres pg_isready -U postgres; do
    echo "PostgreSQL не готов, ждем..."
    sleep 2
done

echo "✅ PostgreSQL готов"

# Проверяем, существует ли база данных
echo "🔍 Проверка существования базы данных..."
DB_EXISTS=$(docker-compose -f docker-compose.production.yml exec -T postgres psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='agb_passports'")

if [ "$DB_EXISTS" = "1" ]; then
    echo "⚠️  База данных уже существует. Удаляем старую версию..."
    docker-compose -f docker-compose.production.yml exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS agb_passports;"
fi

# Создаем базу данных
echo "📦 Создание базы данных..."
docker-compose -f docker-compose.production.yml exec -T postgres psql -U postgres -c "CREATE DATABASE agb_passports;"

# Восстанавливаем данные из бекапа
echo "📥 Восстановление данных из бекапа..."
docker-compose -f docker-compose.production.yml exec -T postgres psql -U postgres -d agb_passports < "$BACKUP_FILE"

# Проверяем восстановление
echo "🔍 Проверка восстановленных данных..."
USERS_COUNT=$(docker-compose -f docker-compose.production.yml exec -T postgres psql -U postgres -d agb_passports -tAc "SELECT COUNT(*) FROM users;")
NOMENCLATURE_COUNT=$(docker-compose -f docker-compose.production.yml exec -T postgres psql -U postgres -d agb_passports -tAc "SELECT COUNT(*) FROM ved_nomenclature;")
PASSPORTS_COUNT=$(docker-compose -f docker-compose.production.yml exec -T postgres psql -U postgres -d agb_passports -tAc "SELECT COUNT(*) FROM ved_passports;")

echo "📊 Статистика восстановленных данных:"
echo "   👥 Пользователи: $USERS_COUNT"
echo "   📦 Номенклатура: $NOMENCLATURE_COUNT"
echo "   📄 Паспорта: $PASSPORTS_COUNT"

# Проверяем правильность артикулов
echo "🔍 Проверка артикулов..."
SAMPLE_ARTICLE=$(docker-compose -f docker-compose.production.yml exec -T postgres psql -U postgres -d agb_passports -tAc "SELECT article FROM ved_nomenclature LIMIT 1;")
if [[ "$SAMPLE_ARTICLE" =~ ^350[0-9]{4}$ ]]; then
    echo "✅ Артикулы в правильном формате: $SAMPLE_ARTICLE"
else
    echo "⚠️  Артикул в неожиданном формате: $SAMPLE_ARTICLE"
fi

echo "🎉 Инициализация базы данных завершена успешно!"
echo ""
echo "📋 Следующие шаги:"
echo "   1. Запустите приложение: docker-compose -f docker-compose.production.yml up -d"
echo "   2. Проверьте логи: docker-compose -f docker-compose.production.yml logs"
echo "   3. Откройте приложение: http://localhost"
echo ""
echo "🔐 Данные для входа:"
echo "   Логин: admin"
echo "   Пароль: admin123"

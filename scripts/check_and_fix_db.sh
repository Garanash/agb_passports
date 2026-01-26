#!/bin/bash

# Скрипт для проверки и исправления подключения к базе данных

echo "🔍 Проверка подключения к базе данных..."

# Проверяем, запущен ли контейнер PostgreSQL
if ! docker ps | grep -q agb_postgres; then
    echo "❌ Контейнер agb_postgres не запущен!"
    echo "Запускаем контейнеры..."
    docker-compose up -d postgres
    sleep 5
fi

# Проверяем, запущен ли контейнер backend
if ! docker ps | grep -q agb_backend; then
    echo "❌ Контейнер agb_backend не запущен!"
    echo "Запускаем контейнеры..."
    docker-compose up -d backend
    sleep 5
fi

echo "✅ Контейнеры запущены"

# Проверяем подключение к базе данных из контейнера PostgreSQL
echo "🔍 Проверка подключения к PostgreSQL..."
docker exec agb_postgres psql -U postgres -d agb_passports -c "SELECT 1;" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL доступен"
else
    echo "❌ Ошибка подключения к PostgreSQL"
    echo "Проверяем пароль..."
    
    # Пытаемся установить пароль
    docker exec -e PGPASSWORD=password agb_postgres psql -U postgres -c "ALTER ROLE postgres WITH PASSWORD 'password';" 2>&1 || \
    docker exec agb_postgres psql -U postgres -c "ALTER ROLE postgres WITH PASSWORD 'password';" 2>&1
    
    echo "✅ Пароль установлен"
fi

# Проверяем подключение из backend контейнера
echo "🔍 Проверка подключения из backend..."
docker exec agb_backend python -c "
import os
import sys
sys.path.append('/app')
from backend.database import engine
try:
    with engine.connect() as conn:
        result = conn.execute('SELECT 1')
        print('✅ Подключение к БД из backend работает')
except Exception as e:
    print(f'❌ Ошибка подключения из backend: {e}')
    sys.exit(1)
" 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Все проверки пройдены!"
else
    echo "❌ Обнаружены проблемы с подключением"
    echo "Перезапускаем backend..."
    docker-compose restart backend
    sleep 3
    echo "✅ Backend перезапущен"
fi

echo ""
echo "📋 Статус контейнеров:"
docker-compose ps

echo ""
echo "📋 Логи backend (последние 20 строк):"
docker logs --tail 20 agb_backend

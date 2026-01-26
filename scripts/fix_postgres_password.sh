#!/bin/bash
# Скрипт для исправления пароля PostgreSQL на сервере

echo "Исправление пароля PostgreSQL..."

# Пробуем несколько вариантов пароля
PASSWORDS=("password" "agb_passports_2024" "postgres")

for PWD in "${PASSWORDS[@]}"; do
    echo "Пробуем пароль: $PWD"
    docker exec agb_postgres psql -U postgres -c "ALTER ROLE postgres WITH PASSWORD 'password';" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ Пароль успешно установлен!"
        break
    fi
done

# Перезапускаем бэкенд
echo "Перезапуск бэкенда..."
docker restart agb_backend

echo "Ожидание запуска бэкенда..."
sleep 10

# Проверяем статус
echo "Проверка статуса..."
docker ps --format "table {{.Names}}\t{{.Status}}"

echo "Проверка логов бэкенда..."
docker logs agb_backend --tail 10

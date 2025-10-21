#!/bin/bash

# Скрипт для деплоя AGB Passports на продакшн сервер

set -e

echo "🚀 Начинаем деплой AGB Passports..."

# Проверяем наличие необходимых файлов
if [ ! -f "docker-compose.prod.yml" ]; then
    echo "❌ Файл docker-compose.prod.yml не найден!"
    exit 1
fi

if [ ! -f "nginx.conf" ]; then
    echo "❌ Файл nginx.conf не найден!"
    exit 1
fi

# Проверяем наличие переменных окружения
if [ ! -f ".env.prod" ]; then
    echo "⚠️  Файл .env.prod не найден. Создаем из примера..."
    cp env.prod.example .env.prod
    echo "📝 Пожалуйста, отредактируйте файл .env.prod с вашими настройками!"
    echo "   Особенно важно изменить:"
    echo "   - POSTGRES_PASSWORD"
    echo "   - SECRET_KEY"
    echo "   - ALLOWED_HOSTS"
    echo "   - NEXT_PUBLIC_API_URL"
    exit 1
fi

# Останавливаем существующие контейнеры
echo "🛑 Останавливаем существующие контейнеры..."
docker-compose -f docker-compose.prod.yml down || true

# Удаляем старые образы (опционально)
read -p "🗑️  Удалить старые Docker образы? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Удаляем старые образы..."
    docker system prune -f
fi

# Собираем новые образы
echo "🔨 Собираем Docker образы..."
docker-compose -f docker-compose.prod.yml build --no-cache

# Запускаем сервисы
echo "🚀 Запускаем сервисы..."
docker-compose -f docker-compose.prod.yml up -d

# Ждем запуска базы данных
echo "⏳ Ждем запуска базы данных..."
sleep 10

# Проверяем статус сервисов
echo "📊 Проверяем статус сервисов..."
docker-compose -f docker-compose.prod.yml ps

# Проверяем логи
echo "📋 Последние логи backend:"
docker-compose -f docker-compose.prod.yml logs --tail=20 backend

echo "📋 Последние логи frontend:"
docker-compose -f docker-compose.prod.yml logs --tail=20 frontend

# Проверяем доступность API
echo "🔍 Проверяем доступность API..."
sleep 5
if curl -f http://localhost/api/v1/passports/health > /dev/null 2>&1; then
    echo "✅ API доступен!"
else
    echo "❌ API недоступен. Проверьте логи:"
    docker-compose -f docker-compose.prod.yml logs backend
fi

# Проверяем доступность фронтенда
echo "🔍 Проверяем доступность фронтенда..."
if curl -f http://localhost > /dev/null 2>&1; then
    echo "✅ Фронтенд доступен!"
else
    echo "❌ Фронтенд недоступен. Проверьте логи:"
    docker-compose -f docker-compose.prod.yml logs frontend
fi

echo ""
echo "🎉 Деплой завершен!"
echo "🌐 Приложение доступно по адресу: http://localhost"
echo "📊 Мониторинг контейнеров: docker-compose -f docker-compose.prod.yml ps"
echo "📋 Просмотр логов: docker-compose -f docker-compose.prod.yml logs -f [service_name]"
echo ""
echo "🔧 Полезные команды:"
echo "   Остановить: docker-compose -f docker-compose.prod.yml down"
echo "   Перезапустить: docker-compose -f docker-compose.prod.yml restart"
echo "   Обновить: ./deploy.sh"
echo ""

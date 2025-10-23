#!/bin/bash

# Быстрый старт AGB Passports
# Использование: ./quick_start.sh

set -e

echo "🚀 Быстрый старт AGB Passports..."

# Проверяем наличие Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен!"
    echo "Установите Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose не установлен!"
    echo "Установите Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Создаем файл окружения, если его нет
if [ ! -f ".env.production" ]; then
    echo "📝 Создание файла окружения..."
    cp env.production.example .env.production
    echo "✅ Файл .env.production создан"
    echo "⚠️  Не забудьте изменить пароли в .env.production!"
fi

# Запускаем развертывание
echo "🚀 Запуск развертывания..."
./deploy.sh

echo ""
echo "🎉 Готово! Приложение доступно по адресу: http://localhost"
echo "🔐 Логин: admin, Пароль: admin123"

#!/bin/bash

# Быстрый запуск AGB Passports в Docker

echo "🐳 AGB Passports - Быстрый запуск в Docker"
echo ""

# Проверяем наличие Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен. Установите Docker и попробуйте снова."
    exit 1
fi

# Проверяем наличие docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose не установлен. Установите docker-compose и попробуйте снова."
    exit 1
fi

echo "🚀 Запускаем AGB Passports..."
docker-compose up -d

echo ""
echo "⏳ Ждем готовности сервисов..."
sleep 10

echo ""
echo "📋 Статус сервисов:"
docker-compose ps

echo ""
echo "🎉 AGB Passports успешно запущен!"
echo ""
echo "📱 Приложение доступно по адресам:"
echo "   Frontend: http://localhost:3001"
echo "   Backend API: http://localhost:8000"
echo "   API документация: http://localhost:8000/docs"
echo "   PostgreSQL: localhost:5435"
echo ""
echo "🛠️  Полезные команды:"
echo "   docker-compose logs -f          # Просмотр логов"
echo "   docker-compose down              # Остановка всех сервисов"
echo "   docker-compose restart backend   # Перезапуск backend"
echo "   docker-compose restart frontend  # Перезапуск frontend"

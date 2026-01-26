#!/bin/bash

# Скрипт для запуска AGB Passports в Docker

echo "🐳 Запуск AGB Passports в Docker..."

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

# Останавливаем существующие контейнеры
echo "🛑 Останавливаем существующие контейнеры..."
docker-compose down

# Собираем образы
echo "🔨 Собираем Docker образы..."
docker-compose build

# Запускаем сервисы
echo "🚀 Запускаем сервисы..."
docker-compose up -d postgres

# Ждем готовности PostgreSQL
echo "⏳ Ждем готовности PostgreSQL..."
sleep 10

# Запускаем backend
echo "🔧 Запускаем backend..."
docker-compose up -d backend

# Загружаем номенклатуры
echo "📊 Загружаем номенклатуры из Excel файла..."
docker-compose run --rm nomenclature_loader

# Запускаем frontend
echo "🎨 Запускаем frontend..."
docker-compose up -d frontend

# Показываем статус
echo "📋 Статус сервисов:"
docker-compose ps

echo ""
echo "🎉 AGB Passports запущен в Docker!"
echo ""
echo "📱 Приложение доступно по адресам:"
echo "   Frontend: http://localhost:3000"
echo "   Backend API: http://localhost:8000"
echo "   API документация: http://localhost:8000/docs"
echo "   PostgreSQL: localhost:5432"
echo ""
echo "🛠️  Полезные команды:"
echo "   docker-compose logs -f          # Просмотр логов"
echo "   docker-compose down              # Остановка всех сервисов"
echo "   docker-compose restart backend   # Перезапуск backend"
echo "   docker-compose restart frontend  # Перезапуск frontend"

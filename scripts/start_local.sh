#!/bin/bash
echo "🚀 Запуск проекта локально..."

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен!"
    exit 1
fi

# Создание папки templates
mkdir -p templates
echo "✅ Папка templates создана"

# Копирование шаблонов (если нужно)
if [ ! -f "templates/sticker_template.docx" ] && [ -f "backend/utils/templates/sticker_template.docx" ]; then
    cp backend/utils/templates/sticker_template.docx templates/
    echo "✅ Шаблон наклеек скопирован"
fi

if [ ! -f "templates/logo.png" ] && [ -f "backend/utils/templates/logo.png" ]; then
    cp backend/utils/templates/logo.png templates/
    echo "✅ Логотип скопирован"
fi

# Остановка старых контейнеров
echo "🛑 Остановка старых контейнеров..."
docker compose down

# Запуск
echo "🚀 Запуск контейнеров..."
docker compose up -d

# Ожидание запуска
echo "⏳ Ожидание запуска сервисов..."
sleep 10

# Проверка статуса
echo "📊 Статус сервисов:"
docker compose ps

echo ""
echo "✅ Проект запущен!"
echo "🌐 Frontend: http://localhost:80"
echo "🔧 Backend API: http://localhost:8000"
echo "📚 API Docs: http://localhost:8000/docs"
echo ""
echo "Для просмотра логов: docker compose logs -f backend"

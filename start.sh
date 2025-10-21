#!/bin/bash

# Скрипт для запуска приложения паспортов коронок

echo "🚀 Запуск приложения AGB Passports..."

# Проверяем наличие Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 не найден. Установите Python 3.8+"
    exit 1
fi

# Проверяем наличие pip
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 не найден. Установите pip"
    exit 1
fi

# Устанавливаем зависимости
echo "📦 Установка зависимостей..."
pip3 install -r requirements.txt

# Инициализируем данные
echo "🗄️ Инициализация базы данных..."
python3 -c "from backend.init_data import init_test_data; init_test_data()"

# Запускаем приложение
echo "🌟 Запуск сервера..."
echo "📱 Приложение будет доступно по адресу: http://localhost:8000"
echo "📚 API документация: http://localhost:8000/docs"
echo "🔄 Для остановки нажмите Ctrl+C"

python3 backend/main.py

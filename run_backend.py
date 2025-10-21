#!/usr/bin/env python3
"""
Скрипт запуска AGB Passports приложения
"""

import sys
import os

# Добавляем путь к проекту в PYTHONPATH
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, project_root)

# Импортируем и запускаем приложение
from backend.main import app

if __name__ == "__main__":
    import uvicorn
    print("🚀 Запуск AGB Passports API...")
    print("📱 API будет доступно по адресу: http://localhost:8000")
    print("📚 Документация API: http://localhost:8000/docs")
    print("🔄 Для остановки нажмите Ctrl+C")
    uvicorn.run(app, host="0.0.0.0", port=8000)

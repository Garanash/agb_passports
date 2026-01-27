"""
Основное приложение для создания паспортов коронок
"""

from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os
from dotenv import dotenv_values

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Загружаем переменные окружения из config.env (если существует)
config_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "config.env")
if os.path.exists(config_path):
    config = dotenv_values(config_path)
    for key, value in config.items():
        if key not in os.environ:
            os.environ[key] = value
else:
    # Используем переменные окружения из Docker/системы
    print("ℹ️ config.env не найден, используем переменные окружения из системы")

from backend.database import create_tables, create_async_tables
from backend.api.v1.endpoints.passports import router as passports_router
from backend.api.v1.endpoints.nomenclature import router as nomenclature_router
from backend.api.v1.endpoints.users import router as users_router
from backend.api.v1.endpoints.templates import router as templates_router
from backend.api.auth import router as auth_router

# Создаем приложение FastAPI
app = FastAPI(
    title="AGB Passports API",
    description="API для создания паспортов коронок",
    version="1.0.0"
)

# Настройка CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене указать конкретные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключение статических файлов
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

# Подключение роутеров
app.include_router(auth_router, prefix="/api/v1/auth", tags=["Аутентификация"])
app.include_router(passports_router, prefix="/api/v1/passports", tags=["Паспорта"])
app.include_router(nomenclature_router, prefix="/api/v1/nomenclature", tags=["Номенклатура"])
app.include_router(users_router, prefix="/api/v1/users", tags=["Пользователи"])
app.include_router(templates_router, prefix="/api/v1/templates", tags=["Шаблоны"])

@app.on_event("startup")
async def startup_event():
    """Инициализация при запуске"""
    # Создаем таблицы в базе данных
    create_tables()
    await create_async_tables()
    print("✅ База данных инициализирована")

@app.get("/")
async def root():
    """Корневой эндпоинт"""
    return {
        "message": "AGB Passports API",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health")
async def health_check():
    """Проверка здоровья API"""
    return {
        "status": "healthy",
        "service": "AGB Passports API",
        "version": "1.0.0"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

"""
Основное приложение для создания паспортов коронок
"""

from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.database import create_tables, create_async_tables
from backend.api.v1.endpoints.passports import router as passports_router
from backend.api.v1.endpoints.nomenclature import router as nomenclature_router
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

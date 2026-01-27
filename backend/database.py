"""
Настройка базы данных для приложения паспортов коронок
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
import os

# Настройки базы данных PostgreSQL
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres@127.0.0.1:5432/agb_passports")
ASYNC_DATABASE_URL = os.getenv("ASYNC_DATABASE_URL", "postgresql+asyncpg://postgres@127.0.0.1:5432/agb_passports")

# Проверяем, что DATABASE_URL содержит пароль (если не указан в переменных окружения)
if "@" in DATABASE_URL and ":" not in DATABASE_URL.split("@")[0].split("//")[1]:
    # Если пароль не указан в URL, но должен быть
    print("⚠️ ВНИМАНИЕ: DATABASE_URL может не содержать пароль. Проверьте переменные окружения.")

# Синхронная база данных с улучшенной обработкой ошибок
try:
    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,  # Проверка соединения перед использованием
        pool_recycle=3600,   # Переиспользование соединений
        echo=False
    )
except Exception as e:
    print(f"❌ Ошибка создания engine для синхронной БД: {e}")
    raise

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Асинхронная база данных
try:
    async_engine = create_async_engine(
        ASYNC_DATABASE_URL,
        echo=False,
        pool_pre_ping=True,
        pool_recycle=3600
    )
except Exception as e:
    print(f"❌ Ошибка создания async_engine для асинхронной БД: {e}")
    raise

# Для SQLAlchemy 1.4 создаем AsyncSession напрямую через async_engine
# async_sessionmaker появился только в SQLAlchemy 2.0
# Используем альтернативный подход для 1.4
def get_async_session():
    """Создает асинхронную сессию (для SQLAlchemy 1.4)"""
    return AsyncSession(bind=async_engine, expire_on_commit=False)

Base = declarative_base()

def get_db():
    """Получение сессии базы данных"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

async def get_async_db():
    """Получение асинхронной сессии базы данных"""
    async with AsyncSession(bind=async_engine, expire_on_commit=False) as session:
        try:
            yield session
        finally:
            await session.close()

def create_tables():
    """Создание таблиц в базе данных"""
    from .models import Base
    Base.metadata.create_all(bind=engine)

async def create_async_tables():
    """Создание таблиц в асинхронной базе данных"""
    from .models import Base
    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

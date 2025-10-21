#!/usr/bin/env python3
"""
Скрипт для создания суперпользователя админа
"""

import os
import sys
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from passlib.context import CryptContext

# Добавляем корневую директорию в путь
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.models import User, Base
from backend.database import get_db_url

# Контекст для хеширования паролей
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password: str) -> str:
    """Хеширование пароля"""
    return pwd_context.hash(password)

def create_admin_user():
    """Создание суперпользователя админа"""

    # Получаем URL базы данных
    database_url = get_db_url()

    # Создаем движок базы данных
    engine = create_engine(database_url)

    # Создаем таблицы если их нет
    Base.metadata.create_all(bind=engine)

    # Создаем сессию
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()

    try:
        # Проверяем, существует ли уже админ
        admin_user = db.query(User).filter(User.role == "admin").first()

        if admin_user:
            print("❌ Админ уже существует!")
            print(f"   Username: {admin_user.username}")
            print(f"   Email: {admin_user.email}")
            return

        # Создаем админа
        admin_username = "admin"
        admin_email = "admin@agb-passports.ru"
        admin_password = "admin123"  # В продакшене использовать сильный пароль
        admin_full_name = "Супер Администратор"

        # Временно используем простой хеш для избежания проблем с bcrypt
        hashed_password = f"bcrypt${admin_password}"

        admin = User(
            username=admin_username,
            email=admin_email,
            full_name=admin_full_name,
            hashed_password=hashed_password,
            role="admin",
            is_active=True
        )

        db.add(admin)
        db.commit()
        db.refresh(admin)

        print("✅ Суперпользователь админ создан успешно!")
        print(f"   Username: {admin_username}")
        print(f"   Email: {admin_email}")
        print(f"   Password: {admin_password}")
        print("   Role: admin")
        print("")
        print("⚠️  ВАЖНО: Измените пароль админа после первого входа!")
        print("   Рекомендуется использовать сильный пароль в продакшене.")

    except Exception as e:
        print(f"❌ Ошибка при создании админа: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    print("🚀 Создание суперпользователя админа...")
    create_admin_user()
    print("✅ Готово!")

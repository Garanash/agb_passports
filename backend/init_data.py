"""
Скрипт для инициализации тестовых данных в приложении паспортов коронок
"""

import asyncio
from sqlalchemy.orm import Session
from .database import SessionLocal, create_tables
from .models import VEDNomenclature, User, PassportCounter

def init_test_data():
    """Инициализация тестовых данных"""
    # Создаем таблицы
    create_tables()
    
    db = SessionLocal()
    try:
        # Создаем тестового пользователя
        test_user = db.query(User).filter(User.username == "test_user").first()
        if not test_user:
            test_user = User(
                username="test_user",
                email="test@example.com",
                full_name="Тестовый пользователь",
                role="admin",
                is_active=True
            )
            db.add(test_user)
            db.commit()
            print("✅ Создан тестовый пользователь")
        
        # Создаем тестовую номенклатуру
        test_nomenclature = [
            {
                "code_1c": "3501040",
                "name": "Алмазная буровая коронка NQ 3-5",
                "article": "3501040",
                "matrix": "NQ",
                "drilling_depth": "3-5",
                "height": "50",
                "thread": "NQ",
                "product_type": "коронка"
            },
            {
                "code_1c": "3501041",
                "name": "Алмазная буровая коронка HQ 5-7",
                "article": "3501041",
                "matrix": "HQ",
                "drilling_depth": "5-7",
                "height": "60",
                "thread": "HQ",
                "product_type": "коронка"
            },
            {
                "code_1c": "3501042",
                "name": "Алмазная буровая коронка PQ 7-9",
                "article": "3501042",
                "matrix": "PQ",
                "drilling_depth": "7-9",
                "height": "70",
                "thread": "PQ",
                "product_type": "коронка"
            },
            {
                "code_1c": "3502001",
                "name": "Расширитель NQ",
                "article": "3502001",
                "matrix": "NQ",
                "height": "100",
                "thread": "NQ",
                "product_type": "расширитель"
            },
            {
                "code_1c": "3503001",
                "name": "Башмак NQ",
                "article": "3503001",
                "matrix": "NQ",
                "height": "50",
                "thread": "NQ",
                "product_type": "башмак"
            }
        ]
        
        for nom_data in test_nomenclature:
            existing = db.query(VEDNomenclature).filter(VEDNomenclature.code_1c == nom_data["code_1c"]).first()
            if not existing:
                nomenclature = VEDNomenclature(**nom_data)
                db.add(nomenclature)
        
        db.commit()
        print("✅ Создана тестовая номенклатура")
        
        # Создаем счетчик для текущего года
        from datetime import datetime
        current_year = datetime.now().year
        counter_name = f"ved_passport_{current_year}"
        
        existing_counter = db.query(PassportCounter).filter(PassportCounter.counter_name == counter_name).first()
        if not existing_counter:
            counter = PassportCounter(
                counter_name=counter_name,
                current_value=0,
                prefix="",
                suffix=str(current_year)[-2:]
            )
            db.add(counter)
            db.commit()
            print(f"✅ Создан счетчик для года {current_year}")
        
        print("🎉 Инициализация данных завершена успешно!")
        
    except Exception as e:
        print(f"❌ Ошибка при инициализации данных: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    init_test_data()

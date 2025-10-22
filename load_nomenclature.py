"""
Скрипт для загрузки номенклатур из Excel файла в базу данных
"""

import pandas as pd
import sys
import os
from sqlalchemy.orm import Session

# Добавляем путь к проекту
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.database import get_db, engine
from backend.models import VEDNomenclature

def load_nomenclature_from_excel(excel_file_path: str):
    """Загрузка номенклатур из Excel файла"""
    
    try:
        # Читаем Excel файл с правильными заголовками
        df = pd.read_excel(excel_file_path, header=1)  # Заголовки в строке 1
        
        print(f"📊 Загружен Excel файл: {excel_file_path}")
        print(f"📋 Найдено строк: {len(df)}")
        print(f"📋 Колонки: {list(df.columns)}")
        
        # Создаем сессию базы данных
        db = Session(engine)
        
        # Создаем таблицы если их нет
        from backend.models import Base
        Base.metadata.create_all(bind=engine)
        print("✅ Таблицы созданы")
        
        # Очищаем существующие номенклатуры
        try:
            db.query(VEDNomenclature).delete()
            db.commit()
            print("✅ Существующие номенклатуры удалены")
        except Exception as e:
            print(f"⚠️ Ошибка при удалении номенклатур: {e}")
            db.rollback()
        
        # Загружаем новые номенклатуры
        loaded_count = 0
        print(f"🔍 Начинаем обработку {len(df)} строк...")
        
        for index in range(len(df)):
            try:
                # Получаем данные из колонок (используем индексы, так как названия колонок неправильные)
                columns = list(df.columns)
                if len(columns) < 3:
                    print(f"❌ Недостаточно колонок в строке {index+1}")
                    continue
                
                # Извлекаем данные по позициям колонок
                # Новая структура: [Артикул, Наименование, Код]
                article = str(df.iloc[index, 0]) if not pd.isna(df.iloc[index, 0]) else ''
                name = str(df.iloc[index, 1]) if not pd.isna(df.iloc[index, 1]) else ''
                code_1c = str(df.iloc[index, 2]) if not pd.isna(df.iloc[index, 2]) else ''
                
                # Пропускаем пустые строки
                if not article or not code_1c or not name:
                    print(f"❌ Пустая строка {index+1}: article='{article}', code_1c='{code_1c}', name='{name}'")
                    continue
                
                print(f"📝 Обрабатываем строку {index+1}: {article} | {code_1c} | {name}")
                
                # Парсим информацию из названия коронки
                matrix = 'NQ'  # По умолчанию
                drilling_depth = '05-07'  # По умолчанию
                height = '12'  # По умолчанию
                
                # Извлекаем матрицу (NQ, HQ, PQ, etc.)
                if 'NQ' in name:
                    matrix = 'NQ'
                elif 'HQ' in name:
                    matrix = 'HQ'
                elif 'PQ' in name:
                    matrix = 'PQ'
                elif 'BQ' in name:
                    matrix = 'BQ'
                elif 'HWT' in name:
                    matrix = 'HWT'
                elif 'PWT' in name:
                    matrix = 'PWT'
                elif 'HQ3' in name:
                    matrix = 'HQ3'
                
                # Извлекаем глубину бурения
                import re
                depth_match = re.search(r'(\d{2}-\d{2})', name)
                if depth_match:
                    drilling_depth = depth_match.group(1)
                
                # Извлекаем высоту
                height_match = re.search(r'высота (\d+) мм', name)
                if height_match:
                    height = height_match.group(1)
                
                # Определяем тип продукта
                product_type = 'коронка'  # По умолчанию
                if 'коронка' in name.lower():
                    product_type = 'коронка'
                elif 'расширитель' in name.lower():
                    product_type = 'расширитель'
                elif 'башмак' in name.lower():
                    product_type = 'башмак'
                
                # Определяем резьбу
                thread = matrix  # По умолчанию резьба = матрица
                thread_match = re.search(r'резьба (\w+)', name)
                if thread_match:
                    thread = thread_match.group(1)
                
                # Создаем номенклатуру (меняем местами article и code_1c)
                nomenclature = VEDNomenclature(
                    code_1c=article,  # Код 1С теперь в поле code_1c
                    name=name,
                    drilling_depth=drilling_depth,
                    matrix=matrix,
                    article=code_1c,  # Артикул теперь в поле article
                    height=height,
                    thread=thread,
                    product_type=product_type,
                    is_active=True
                )
                
                db.add(nomenclature)
                loaded_count += 1
                print(f"✅ Загружена: {code_1c} - {name}")
                
            except Exception as e:
                print(f"❌ Ошибка при загрузке строки {index+1}: {e}")
                continue
        
        # Сохраняем изменения
        db.commit()
        db.close()
        
        print(f"✅ Успешно загружено {loaded_count} номенклатур")
        return True
        
    except Exception as e:
        print(f"❌ Ошибка при загрузке Excel файла: {e}")
        return False

def create_admin_user(db):
    """Создание суперпользователя админа"""
    from backend.models import User
    from passlib.context import CryptContext

    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

    # Проверяем, существует ли уже админ
    admin_user = db.query(User).filter(User.role == "admin").first()

    if not admin_user:
        print("👑 Создаю суперпользователя админа...")

        # Временно используем простой хэш для избежания проблем с bcrypt
        import hashlib
        hashed_password = f"sha256${hashlib.sha256('admin'.encode()).hexdigest()}"

        admin = User(
            username="admin",
            email="admin@agb-passports.ru",
            full_name="Супер Администратор",
            hashed_password=hashed_password,
            role="admin",
            is_active=True
        )

        db.add(admin)
        db.commit()
        print("✅ Админ создан: admin / admin")
    else:
        print("👑 Админ уже существует")

def main():
    """Основная функция"""
    excel_file = "/app/nomenclature.xlsx"

    if not os.path.exists(excel_file):
        print(f"❌ Файл {excel_file} не найден")
        return

    print("🚀 Начинаем загрузку номенклатур из Excel файла...")

    # Создаем сессию базы данных
    from sqlalchemy.orm import sessionmaker
    Session = sessionmaker(bind=engine)
    db = Session()

    try:
        # Временно отключаем создание админа для отладки
        # create_admin_user(db)

        if load_nomenclature_from_excel(excel_file):
            print("🎉 Загрузка завершена успешно!")
        else:
            print("💥 Загрузка завершилась с ошибками")
    finally:
        db.close()

if __name__ == "__main__":
    main()

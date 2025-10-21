#!/usr/bin/env python3
"""
Унифицированный скрипт загрузки данных для AGB Passports
Поддерживает загрузку номенклатур, создание админа и инициализацию базы данных
"""

import os
import sys
import pandas as pd
import hashlib
from datetime import datetime
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError

# Добавляем корневую директорию в путь для импортов
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.models import Base, User, VEDNomenclature, VedPassport, PassportCounter
from backend.database import get_db_url

class DataLoader:
    """Класс для загрузки данных в базу AGB Passports"""

    def __init__(self):
        self.database_url = get_db_url()
        self.engine = create_engine(self.database_url)
        self.Session = sessionmaker(bind=self.engine)

    def create_tables(self):
        """Создание всех таблиц в базе данных"""
        try:
            Base.metadata.create_all(bind=self.engine)
            print("✅ Все таблицы созданы успешно")
            return True
        except Exception as e:
            print(f"❌ Ошибка при создании таблиц: {e}")
            return False

    def create_admin_user(self, db):
        """Создание суперпользователя админа"""
        try:
            # Проверяем, существует ли уже админ
            admin_user = db.query(User).filter(User.role == "admin").first()

            if admin_user:
                print("👑 Админ уже существует")
                return admin_user

            print("👑 Создаю суперпользователя админа...")

            # Создаем хеш пароля
            password = "admin"
            password_hash = f"sha256${hashlib.sha256(password.encode()).hexdigest()}"

            admin = User(
                username="admin",
                email="admin@agb-passports.ru",
                full_name="Супер Администратор",
                hashed_password=password_hash,
                role="admin",
                is_active=True
            )

            db.add(admin)
            db.commit()
            db.refresh(admin)

            print("✅ Админ создан успешно"            print(f"   Логин: {admin.username}")
            print(f"   Пароль: {password}")
            print(f"   Роль: {admin.role}")

            return admin

        except Exception as e:
            print(f"❌ Ошибка при создании админа: {e}")
            db.rollback()
            return None

    def load_nomenclature_from_excel(self, excel_file_path: str, db):
        """Загрузка номенклатур из Excel файла"""

        try:
            # Читаем Excel файл с правильными заголовками
            df = pd.read_excel(excel_file_path, header=1)  # Заголовки в строке 1

            print(f"📊 Загружен Excel файл: {excel_file_path}")
            print(f"📋 Найдено строк: {len(df)}")
            print(f"📋 Колонки: {list(df.columns)}")

            # Очищаем существующие номенклатуры
            db.query(VEDNomenclature).delete()

            # Загружаем новые номенклатуры
            loaded_count = 0

            for index, row in df.iterrows():
                try:
                    # Пропускаем пустые строки
                    if pd.isna(row.get('Код 1С')) or pd.isna(row.get('Наименование')):
                        continue

                    # Извлекаем информацию из названия
                    name = str(row.get('Наименование', ''))
                    code_1c = str(row.get('Код 1С', ''))
                    article = str(row.get('Артикул', ''))

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

                    # Извлекаем глубину бурения
                    import re
                    depth_match = re.search(r'(\d{2}-\d{2})', name)
                    if depth_match:
                        drilling_depth = depth_match.group(1)

                    # Извлекаем высоту
                    height_match = re.search(r'высота (\d+) мм', name)
                    if height_match:
                        height = height_match.group(1)

                    # Определяем тип изделия
                    product_type = 'коронка'
                    if 'расширитель' in name.lower():
                        product_type = 'расширитель'
                    elif 'башмак' in name.lower():
                        product_type = 'башмак'

                    # Создаем номенклатуру
                    nomenclature = VEDNomenclature(
                        code_1c=code_1c,
                        name=name,
                        article=article,
                        matrix=matrix,
                        drilling_depth=drilling_depth,
                        height=height,
                        thread='',
                        product_type=product_type,
                        is_active=True
                    )

                    db.add(nomenclature)
                    loaded_count += 1

                    if loaded_count % 5 == 0:  # Показываем прогресс каждые 5 элементов
                        print(f"   Загружено: {loaded_count} номенклатур...")

                except Exception as e:
                    print(f"❌ Ошибка при загрузке строки {index+1}: {e}")
                    continue

            # Сохраняем изменения
            db.commit()

            print(f"✅ Успешно загружено {loaded_count} номенклатур")
            return True

        except Exception as e:
            print(f"❌ Ошибка при загрузке Excel файла: {e}")
            return False

    def run(self):
        """Основной метод запуска загрузки данных"""

        print("🚀 Запуск загрузки данных AGB Passports...")
        print("=" * 50)

        # Создаем таблицы
        if not self.create_tables():
            return False

        # Создаем сессию базы данных
        db = self.Session()

        try:
            # Создаем админа
            admin = self.create_admin_user(db)
            if not admin:
                return False

            # Загружаем номенклатуры
            excel_file = os.path.join(os.path.dirname(__file__), "Номенклатура алмазный инстурмент ALFA.xlsx")

            if not os.path.exists(excel_file):
                print(f"❌ Excel файл не найден: {excel_file}")
                return False

            if not self.load_nomenclature_from_excel(excel_file, db):
                return False

            print("=" * 50)
            print("🎉 Загрузка данных завершена успешно!")
            print("")
            print("📋 Резюме:")
            print(f"   👑 Админ: {admin.username} ({admin.email})")
            print(f"   📦 Номенклатур: {db.query(VEDNomenclature).count()}")
            print(f"   📄 Паспортов: {db.query(VedPassport).count()}")
            print("")
            print("🌐 Доступ к системе:")
            print("   Frontend: http://localhost:3001")
            print("   Backend API: http://localhost:8000")
            print("   API Docs: http://localhost:8000/docs")
            print("")
            print("🔑 Учетные записи:")
            print("   Админ: admin / admin")
            print("   Пользователь: testuser / test123")

            return True

        except Exception as e:
            print(f"❌ Критическая ошибка: {e}")
            db.rollback()
            return False

        finally:
            db.close()

def main():
    """Главная функция"""
    loader = DataLoader()
    success = loader.run()

    if success:
        print("✅ Проект готов к использованию!")
        return 0
    else:
        print("❌ Загрузка данных завершилась с ошибками")
        return 1

if __name__ == "__main__":
    exit(main())

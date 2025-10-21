#!/usr/bin/env python3
"""
Простой скрипт для загрузки номенклатур
"""

import os
import sys
import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Добавляем корневую директорию в путь
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.models import VEDNomenclature, Base

def load_nomenclature_from_excel(excel_file_path: str, db):
    """Загрузка номенклатур из Excel файла"""

    try:
        # Читаем Excel файл с правильными заголовками
        df = pd.read_excel(excel_file_path, header=1)  # Заголовки в строке 1

        print(f"📊 Загружен Excel файл: {excel_file_path}")
        print(f"📋 Найдено строк: {len(df)}")
        print(f"📋 Колонки: {list(df.columns)}")

        # Создаем таблицы если их нет
        Base.metadata.create_all(bind=db.bind)
        print("✅ Таблицы созданы")

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

                # Создаем номенклатуру
                nomenclature = VEDNomenclature(
                    code_1c=code_1c,
                    name=name,
                    drilling_depth=drilling_depth,
                    matrix=matrix,
                    article=article,
                    height=height,
                    thread='',
                    product_type='коронка',
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

        print(f"✅ Успешно загружено {loaded_count} номенклатур")
        return True

    except Exception as e:
        print(f"❌ Ошибка при загрузке Excel файла: {e}")
        return False

def main():
    """Основная функция"""
    excel_file = "/app/nomenclature.xlsx"

    if not os.path.exists(excel_file):
        print(f"❌ Файл {excel_file} не найден")
        return

    # Создаем движок базы данных
    database_url = "postgresql://postgres:password@postgres:5432/agb_passports"
    engine = create_engine(database_url)

    # Создаем сессию
    Session = sessionmaker(bind=engine)
    db = Session()

    try:
        print("🚀 Начинаем загрузку номенклатур из Excel файла...")

        if load_nomenclature_from_excel(excel_file, db):
            print("🎉 Загрузка завершена успешно!")
        else:
            print("💥 Загрузка завершилась с ошибками")
    finally:
        db.close()

if __name__ == "__main__":
    main()

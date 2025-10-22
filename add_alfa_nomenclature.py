#!/usr/bin/env python3
"""
Скрипт для добавления дополнительных номенклатур из файла "Коронки ALFA новые позиции 21.10.25.xlsx"
"""

import pandas as pd
import sys
import os
from sqlalchemy.orm import Session

# Добавляем путь к проекту
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.database import get_db, engine
from backend.models import VEDNomenclature

def add_additional_nomenclature():
    """Добавление дополнительных номенклатур из файла коронок ALFA"""
    
    try:
        # Читаем Excel файл с коронками ALFA
        df = pd.read_excel("Коронки ALFA новые позиции 21.10.25.xlsx", header=1)
        
        print(f"📊 Загружен файл коронок ALFA")
        print(f"📋 Найдено строк: {len(df)}")
        print(f"📋 Колонки: {list(df.columns)}")
        
        # Создаем сессию базы данных
        db = Session(engine)
        
        # Создаем таблицы если их нет
        from backend.models import Base
        Base.metadata.create_all(bind=engine)
        print("✅ Таблицы созданы")
        
        # Загружаем новые номенклатуры
        loaded_count = 0
        
        print(f"🔍 Начинаем обработку {len(df)} строк...")
        
        for index in range(len(df)):
            try:
                # Получаем данные из колонок
                columns = list(df.columns)
                if len(columns) < 3:
                    print(f"❌ Недостаточно колонок в строке {index+1}")
                    continue
                
                # Извлекаем данные по позициям колонок
                # Структура: [Артикул, Код 1С, Наименование]
                article = str(df.iloc[index, 0]) if not pd.isna(df.iloc[index, 0]) else ''
                code_1c = str(df.iloc[index, 1]) if not pd.isna(df.iloc[index, 1]) else ''
                name = str(df.iloc[index, 2]) if not pd.isna(df.iloc[index, 2]) else ''
                
                # Пропускаем пустые строки
                if not article or not code_1c or not name:
                    print(f"❌ Пустая строка {index+1}: article='{article}', code_1c='{code_1c}', name='{name}'")
                    continue
                
                print(f"📝 Обрабатываем строку {index+1}: {article} | {code_1c} | {name}")
                
                # Проверяем, не существует ли уже такая номенклатура
                existing = db.query(VEDNomenclature).filter(VEDNomenclature.code_1c == code_1c).first()
                if existing:
                    print(f"⚠️ Номенклатура с кодом {code_1c} уже существует, пропускаем")
                    continue
                
                # Парсим информацию из названия коронки
                matrix = 'BQ'  # По умолчанию для коронок ALFA
                drilling_depth = '05-07'  # По умолчанию
                height = '12'  # По умолчанию
                
                # Извлекаем матрицу (NQ, HQ, PQ, BQ, etc.)
                import re
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
                print(f"✅ Добавлена: {code_1c} - {name}")
                
            except Exception as e:
                print(f"❌ Ошибка при обработке строки {index+1}: {e}")
                continue
        
        # Сохраняем изменения
        db.commit()
        db.close()
        
        print(f"✅ Успешно добавлено {loaded_count} номенклатур")
        return True
        
    except Exception as e:
        print(f"❌ Ошибка при загрузке файла: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Добавление дополнительных номенклатур коронок ALFA...")
    success = add_additional_nomenclature()
    if success:
        print("🎉 Добавление завершено успешно!")
    else:
        print("💥 Добавление завершилось с ошибками")

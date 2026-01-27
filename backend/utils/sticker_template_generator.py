"""
Генератор наклеек из шаблона Excel с плейсхолдерами
ПРОСТОЙ И ПРАВИЛЬНЫЙ АЛГОРИТМ:
1. Берем шаблон из backend/utils/templates/sticker_template.xlsx
2. Для каждой наклейки: заполняем шаблон данными + генерируем штрихкоды
3. Конвертируем в DOCX и формируем таблицу 2x4 (2 колонки, 4 строки = 8 наклеек на странице)
"""
import os
import io
import tempfile
import sys
from typing import List, Optional

# Опциональный импорт docxtpl - если не установлен, будет использован fallback
try:
    from docxtpl import DocxTemplate, InlineImage
    DOCXTPL_AVAILABLE = True
except ImportError:
    DOCXTPL_AVAILABLE = False
    print("⚠️ docxtpl не установлен, будет использован стандартный метод генерации")

from docx import Document
from docx.shared import Mm
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import qn
from backend.utils.template_manager import get_template_manager
import xml.etree.ElementTree as ET
from io import BytesIO
import shutil

# Импорт для работы с Excel
try:
    from openpyxl import load_workbook
    from openpyxl.drawing.image import Image as OpenpyxlImage
    OPENPYXL_AVAILABLE = True
except ImportError:
    OPENPYXL_AVAILABLE = False
    print("⚠️ openpyxl не установлен, будет использован стандартный метод генерации")

# Импорт Mm для использования в функциях
try:
    from docx.shared import Mm as DocxMm
except:
    DocxMm = Mm


def get_template_path():
    """Получает путь к шаблону наклеек через TemplateManager"""
    manager = get_template_manager()
    template_path = manager.get_template_path("sticker")
    if template_path:
        print(f"✅ Шаблон найден: {template_path}")
        return str(template_path)
    
    print("⚠️ Шаблон не найден, будет использован стандартный метод генерации")
    return None


def generate_stickers_from_template(passports, template_path=None):
    """
    Генерирует DOCX с наклейками из шаблона Excel
    
    ПРОСТОЙ АЛГОРИТМ:
    1. Берем шаблон из backend/utils/templates/sticker_template.xlsx
    2. Для каждой наклейки заполняем шаблон данными + генерируем штрихкоды
    3. Конвертируем Excel в DOCX и формируем таблицу 2x4 (2 колонки, 4 строки = 8 наклеек на странице)
    """
    print(f"🏷️ Начинаем генерацию DOCX наклеек из Excel шаблона для {len(passports)} паспортов")
    sys.stdout.flush()
    
    # Получаем путь к шаблону
    if template_path is None:
        template_path = get_template_path()
    
    if not template_path or not os.path.exists(template_path):
        print(f"⚠️ Шаблон не найден, используем стандартный метод")
        sys.stdout.flush()
        return generate_stickers_standard(passports)
    
    # Проверяем расширение файла
    if template_path.endswith('.xlsx'):
        if not OPENPYXL_AVAILABLE:
            print(f"⚠️ openpyxl не установлен, используем стандартный метод")
            sys.stdout.flush()
            return generate_stickers_standard(passports)
        
        try:
            result = generate_from_excel_template(passports, template_path)
            
            # Проверяем, что результат - это валидный DOCX (ZIP)
            import zipfile
            try:
                zip_buffer = io.BytesIO(result)
                with zipfile.ZipFile(zip_buffer, 'r') as zip_check:
                    if 'word/document.xml' not in zip_check.namelist():
                        raise ValueError("Результат не является валидным DOCX")
                print(f"✅ DOCX успешно сгенерирован из Excel шаблона, размер: {len(result)} байт")
                sys.stdout.flush()
                return result
            except (zipfile.BadZipFile, ValueError) as zip_err:
                print(f"❌ Результат не является валидным DOCX: {zip_err}")
                sys.stdout.flush()
                raise ValueError(f"Сгенерированный файл не является валидным DOCX: {zip_err}")
        except Exception as e:
            print(f"⚠️ Ошибка при использовании Excel шаблона: {e}")
            import traceback
            traceback.print_exc()
            sys.stdout.flush()
            print("🔄 Переключаемся на стандартный метод генерации DOCX...")
            sys.stdout.flush()
            return generate_stickers_standard(passports)
    
    # Fallback для DOCX шаблонов (старая логика)
    elif template_path.endswith('.docx'):
        if not DOCXTPL_AVAILABLE:
            print(f"⚠️ docxtpl не установлен, используем стандартный метод")
            sys.stdout.flush()
            return generate_stickers_standard(passports)
        
        try:
            result = generate_from_template_file(passports, template_path)
            
            # Проверяем, что результат - это валидный DOCX (ZIP)
            import zipfile
            try:
                zip_buffer = io.BytesIO(result)
                with zipfile.ZipFile(zip_buffer, 'r') as zip_check:
                    if 'word/document.xml' not in zip_check.namelist():
                        raise ValueError("Результат не является валидным DOCX")
                print(f"✅ DOCX успешно сгенерирован, размер: {len(result)} байт")
                sys.stdout.flush()
                return result
            except (zipfile.BadZipFile, ValueError) as zip_err:
                print(f"❌ Результат не является валидным DOCX: {zip_err}")
                sys.stdout.flush()
                raise ValueError(f"Сгенерированный файл не является валидным DOCX: {zip_err}")
        except Exception as e:
            print(f"⚠️ Ошибка при использовании шаблона: {e}")
            import traceback
            traceback.print_exc()
            sys.stdout.flush()
            print("🔄 Переключаемся на стандартный метод генерации DOCX...")
            sys.stdout.flush()
            return generate_stickers_standard(passports)
    else:
        print(f"⚠️ Неподдерживаемый формат шаблона: {template_path}")
        sys.stdout.flush()
        return generate_stickers_standard(passports)


def generate_from_excel_template(passports, template_path):
    """
    Генерирует DOCX наклейки из Excel шаблона
    
    АЛГОРИТМ:
    1. Загружаем Excel шаблон через openpyxl
    2. Для каждой наклейки заполняем ячейки данными
    3. Вставляем логотип и штрихкоды как изображения
    4. Конвертируем Excel в DOCX (через промежуточный формат)
    5. Формируем таблицу 2x4 в DOCX
    """
    print(f"📊 Генерация наклеек из Excel шаблона: {len(passports)} паспортов")
    sys.stdout.flush()
    
    from backend.utils.barcode_generator import generate_barcode_image
    
    # Получаем путь к логотипу
    manager = get_template_manager()
    logo_path_obj = manager.get_logo_path()
    logo_path = str(logo_path_obj) if logo_path_obj and logo_path_obj.exists() else None
    
    # Дополнительная проверка и логирование
    if not logo_path:
        # Пробуем альтернативные пути
        alt_paths = [
            '/app/backend/utils/templates/logo.png',
            '/app/templates/logo.png',
            'backend/utils/templates/logo.png',
            'templates/logo.png'
        ]
        for alt_path in alt_paths:
            if os.path.exists(alt_path):
                logo_path = alt_path
                print(f"    ✅ Логотип найден по альтернативному пути: {logo_path}")
                break
        
        if not logo_path:
            print(f"    ⚠️ Логотип не найден ни по одному из путей!")
    else:
        print(f"    ✅ Логотип найден: {logo_path}")
    
    # Создаем новый DOCX документ
    doc = Document()
    
    # Устанавливаем размеры страницы A4 без отступов
    section = doc.sections[0]
    section.page_height = Mm(297)
    section.page_width = Mm(210)
    section.left_margin = Mm(0)
    section.right_margin = Mm(0)
    section.top_margin = Mm(0)
    section.bottom_margin = Mm(0)
    
    # Загружаем Excel шаблон
    wb = load_workbook(template_path)
    ws = wb.active
    
    # Группируем паспорта по 4 на страницу (2x2)
    for page_idx in range(0, len(passports), 4):
        passport_group = passports[page_idx:page_idx+4]
        
        # Создаем таблицу 2x2 для страницы
        table = doc.add_table(rows=2, cols=2)
        
        # Настраиваем размеры таблицы и ячеек
        table.style = 'Table Grid'
        sticker_width = Mm(105)  # Ширина наклейки
        sticker_height = Mm(148.5)  # Высота наклейки = 297/2 (для 2 строк)
        
        for row in table.rows:
            row.height = sticker_height
            for cell in row.cells:
                cell.width = sticker_width
                
                # Убираем все отступы в ячейках для точного заполнения
                tcPr = cell._element.tcPr
                if tcPr is None:
                    tcPr = OxmlElement('w:tcPr')
                    cell._element.insert(0, tcPr)
                
                # Убираем отступы (0 мм)
                tcMar = OxmlElement('w:tcMar')
                for margin_name in ['top', 'left', 'bottom', 'right']:
                    margin = OxmlElement(f'w:{margin_name}')
                    margin.set(qn('w:w'), '0')
                    margin.set(qn('w:type'), 'dxa')
                    tcMar.append(margin)
                tcPr.append(tcMar)
        
        # Заполняем ячейки (2x2 = 4 наклейки на странице)
        for row_idx in range(2):
            for col_idx in range(2):
                idx = row_idx * 2 + col_idx
                cell = table.rows[row_idx].cells[col_idx]
                
                if idx < len(passport_group):
                    passport = passport_group[idx]
                    nomenclature = passport.nomenclature
                    
                    if not nomenclature:
                        continue
                    
                    # Получаем данные
                    production_date = "2025"
                    if passport.created_at:
                        production_date = passport.created_at.strftime("%Y")
                    
                    # Генерируем штрихкоды
                    stock_code = nomenclature.article or getattr(nomenclature, 'code_1c', None) or '3501040'
                    stock_code_barcode_path = generate_barcode_image(stock_code, width_mm=40, height_mm=10)
                    
                    serial_number = passport.passport_number or 'AGB0000125'
                    serial_number_barcode_path = generate_barcode_image(serial_number, width_mm=40, height_mm=10)
                    
                    # СОЗДАЕМ ТАБЛИЦУ ВНУТРИ ЯЧЕЙКИ С ГРАНИЦАМИ, КАК В EXCEL ШАБЛОНЕ
                    # Очищаем ячейку
                    cell.paragraphs[0].clear()
                    
                    # Создаем таблицу 10 строк x 2 колонки с границами
                    inner_table = cell.add_table(rows=10, cols=2)
                    inner_table.style = 'Table Grid'  # Стиль с границами
                    
                    # Настраиваем ширины колонок - по 50% каждая
                    inner_cell_width = sticker_width / 2
                    for row in inner_table.rows:
                        for col_idx in range(2):
                            row.cells[col_idx].width = inner_cell_width
                            
                            # Убираем отступы в ячейках
                            inner_cell = row.cells[col_idx]
                            inner_tcPr = inner_cell._element.tcPr
                            if inner_tcPr is None:
                                inner_tcPr = OxmlElement('w:tcPr')
                                inner_cell._element.insert(0, inner_tcPr)
                            
                            # Устанавливаем ширину ячейки
                            tcW = OxmlElement('w:tcW')
                            tcW.set(qn('w:w'), str(int(inner_cell_width * 20)))  # В twips
                            tcW.set(qn('w:type'), 'dxa')
                            inner_tcPr.append(tcW)
                            
                            # Добавляем отступ 10 пикселей (примерно 3.75 мм) по периметру
                            # 10 пикселей при 96 DPI = примерно 3.75 мм = 75 twips (1 мм = 20 twips)
                            inner_tcMar = OxmlElement('w:tcMar')
                            for margin_name in ['top', 'left', 'bottom', 'right']:
                                margin = OxmlElement(f'w:{margin_name}')
                                margin.set(qn('w:w'), '75')  # 10 пикселей = ~3.75 мм = 75 twips
                                margin.set(qn('w:type'), 'dxa')
                                inner_tcMar.append(margin)
                            inner_tcPr.append(inner_tcMar)
                    
                    # СТРОКА 1: Логотип + "Код номенклатуры:" + штрихкод
                    row1 = inner_table.rows[0]
                    cell_a1 = row1.cells[0]
                    cell_b1 = row1.cells[1]
                    
                    # A1: Логотип нормального размера
                    p_a1 = cell_a1.paragraphs[0]
                    p_a1.alignment = 1  # CENTER
                    if logo_path and os.path.exists(logo_path):
                        try:
                            # Логотип нормального размера (18мм x 5.4мм)
                            logo_run = p_a1.add_run()
                            logo_run.add_picture(logo_path, width=Mm(18), height=Mm(5.4))
                            print(f"    ✅ Логотип добавлен в ячейку A1: {logo_path}, размер: 18мм x 5.4мм")
                        except Exception as e:
                            print(f"    ⚠️ Ошибка добавления логотипа: {e}")
                            import traceback
                            traceback.print_exc()
                    else:
                        print(f"    ⚠️ Логотип не найден для наклейки! Путь: {logo_path}")
                    
                    # B1: "Код номенклатуры:" + штрихкод
                    p_b1 = cell_b1.paragraphs[0]
                    p_b1.alignment = 1  # CENTER
                    p_b1.add_run('Код номенклатуры:')
                    if stock_code_barcode_path and os.path.exists(stock_code_barcode_path):
                        try:
                            p_b1.add_run('\n')
                            barcode_run = p_b1.add_run()
                            barcode_run.add_picture(stock_code_barcode_path, width=Mm(40), height=Mm(10))
                        except Exception as e:
                            print(f"    ⚠️ Ошибка добавления штрихкода stock_code: {e}")
                    
                    # СТРОКА 2: Название номенклатуры (объединенная)
                    row2 = inner_table.rows[1]
                    cell_a2 = row2.cells[0]
                    cell_b2 = row2.cells[1]
                    cell_a2.merge(cell_b2)
                    p_a2 = cell_a2.paragraphs[0]
                    p_a2.alignment = 1  # CENTER
                    nom_name = nomenclature.name or 'Буровой инструмент'
                    p_a2.add_run(nom_name)
                    
                    # СТРОКА 3: Серийный номер (объединенная)
                    row3 = inner_table.rows[2]
                    cell_a3 = row3.cells[0]
                    cell_b3 = row3.cells[1]
                    cell_a3.merge(cell_b3)
                    p_a3 = cell_a3.paragraphs[0]
                    p_a3.alignment = 1  # CENTER
                    p_a3.add_run(serial_number)
                    
                    # СТРОКА 4: Артикул
                    row4 = inner_table.rows[3]
                    cell_a4 = row4.cells[0]
                    cell_b4 = row4.cells[1]
                    cell_a4.paragraphs[0].add_run('Артикул:')
                    cell_b4.paragraphs[0].alignment = 2  # RIGHT
                    cell_b4.paragraphs[0].add_run(stock_code)
                    
                    # СТРОКА 5: Матрица
                    row5 = inner_table.rows[4]
                    cell_a5 = row5.cells[0]
                    cell_b5 = row5.cells[1]
                    cell_a5.paragraphs[0].add_run('Матрица:')
                    cell_b5.paragraphs[0].alignment = 2  # RIGHT
                    matrix_val = nomenclature.matrix or 'NQ'
                    height_val = str(nomenclature.height or getattr(nomenclature, 'drilling_depth', None) or '12')
                    cell_b5.paragraphs[0].add_run(f"{matrix_val} {height_val}")
                    
                    # СТРОКА 6: Промывочные отверстия
                    row6 = inner_table.rows[5]
                    cell_a6 = row6.cells[0]
                    cell_b6 = row6.cells[1]
                    cell_a6.paragraphs[0].add_run('Промывочные отверстия:')
                    cell_b6.paragraphs[0].alignment = 2  # RIGHT
                    waterways_val = str(getattr(nomenclature, 'waterways', None) or '8')
                    cell_b6.paragraphs[0].add_run(waterways_val)
                    
                    # СТРОКА 7: Типоразмер
                    row7 = inner_table.rows[6]
                    cell_a7 = row7.cells[0]
                    cell_b7 = row7.cells[1]
                    cell_a7.paragraphs[0].add_run('Типоразмер:')
                    cell_b7.paragraphs[0].alignment = 2  # RIGHT
                    tool_size = nomenclature.matrix or 'NQ'
                    cell_b7.paragraphs[0].add_run(tool_size)
                    
                    # СТРОКА 8: Серийный номер + штрихкод (объединенная)
                    row8 = inner_table.rows[7]
                    cell_a8 = row8.cells[0]
                    cell_b8 = row8.cells[1]
                    cell_a8.merge(cell_b8)
                    p_a8 = cell_a8.paragraphs[0]
                    p_a8.alignment = 1  # CENTER
                    p_a8.add_run('Серийный номер:')
                    if serial_number_barcode_path and os.path.exists(serial_number_barcode_path):
                        try:
                            p_a8.add_run('\n')
                            barcode_run = p_a8.add_run()
                            barcode_run.add_picture(serial_number_barcode_path, width=Mm(40), height=Mm(10))
                        except Exception as e:
                            print(f"    ⚠️ Ошибка добавления штрихкода serial_number: {e}")
                    
                    # СТРОКА 9: Дата изготовления (объединенная)
                    row9 = inner_table.rows[8]
                    cell_a9 = row9.cells[0]
                    cell_b9 = row9.cells[1]
                    cell_a9.merge(cell_b9)
                    p_a9 = cell_a9.paragraphs[0]
                    p_a9.alignment = 0  # LEFT
                    date_text = 'Дата изготовления: «____»_______________20____г.'
                    p_a9.add_run(date_text)
                    
                    # СТРОКА 10: Сайт (объединенная)
                    row10 = inner_table.rows[9]
                    cell_a10 = row10.cells[0]
                    cell_b10 = row10.cells[1]
                    cell_a10.merge(cell_b10)
                    p_a10 = cell_a10.paragraphs[0]
                    p_a10.alignment = 1  # CENTER
                    p_a10.add_run('www.almazgeobur.ru')
                    
                    # Удаляем временные файлы штрихкодов
                    try:
                        if stock_code_barcode_path and os.path.exists(stock_code_barcode_path):
                            os.unlink(stock_code_barcode_path)
                        if serial_number_barcode_path and os.path.exists(serial_number_barcode_path):
                            os.unlink(serial_number_barcode_path)
                    except:
                        pass
        
        # Добавляем разрыв страницы (кроме последней)
        if page_idx + 8 < len(passports):
            doc.add_page_break()
    
    # Сохраняем в память
    buffer = io.BytesIO()
    doc.save(buffer)
    buffer.seek(0)
    docx_content = buffer.getvalue()
    
    print(f"✅ DOCX с наклейками успешно сгенерирован из Excel, размер: {len(docx_content)} байт")
    sys.stdout.flush()
    
    return docx_content


def generate_from_template_file(passports, template_path):
    """
    ПРОСТОЙ И ПРАВИЛЬНЫЙ АЛГОРИТМ:
    1. Берем шаблон из backend/utils/templates/sticker_template.docx
    2. Для каждой наклейки:
       - Создаем копию шаблона
       - Генерируем штрихкоды
       - Заполняем через docxtpl
       - Копируем содержимое в ячейку таблицы 2x4
    3. Формируем таблицу 2x4 (2 колонки, 4 строки)
    """
    print(f"🔍 Генерация наклеек: {len(passports)} паспортов, шаблон: {template_path}")
    sys.stdout.flush()
    
    if not DOCXTPL_AVAILABLE:
        print(f"⚠️ docxtpl не установлен, используем стандартный метод")
        return generate_stickers_standard(passports)
    
    # Загружаем шаблон для определения размеров
    template_doc = Document(template_path)
    template_section = template_doc.sections[0]
    
    # Определяем размеры страницы шаблона
    template_page_width_mm = template_section.page_width.mm if hasattr(template_section.page_width, 'mm') else template_section.page_width / 36000
    template_page_height_mm = template_section.page_height.mm if hasattr(template_section.page_height, 'mm') else template_section.page_height / 36000
    
    # Размеры наклейки из шаблона
    sticker_width_mm = template_page_width_mm
    sticker_height_mm = template_page_height_mm
    
    # Получаем путь к логотипу
    manager = get_template_manager()
    logo_path_obj = manager.get_logo_path()
    logo_path = str(logo_path_obj) if logo_path_obj and logo_path_obj.exists() else None
    
    # Дополнительная проверка и логирование
    if not logo_path:
        # Пробуем альтернативные пути
        alt_paths = [
            '/app/backend/utils/templates/logo.png',
            '/app/templates/logo.png',
            'backend/utils/templates/logo.png',
            'templates/logo.png'
        ]
        for alt_path in alt_paths:
            if os.path.exists(alt_path):
                logo_path = alt_path
                print(f"    ✅ Логотип найден по альтернативному пути: {logo_path}")
                break
        
        if not logo_path:
            print(f"    ⚠️ Логотип не найден ни по одному из путей!")
    else:
        print(f"    ✅ Логотип найден: {logo_path}")
    
    # Создаем новый документ
    doc = Document()
    
    # Устанавливаем размеры страницы A4 без отступов
    section = doc.sections[0]
    section.page_height = Mm(297)
    section.page_width = Mm(210)
    section.left_margin = Mm(0)
    section.right_margin = Mm(0)
    section.top_margin = Mm(0)
    section.bottom_margin = Mm(0)
    
    # Группируем паспорта по 4 на страницу (таблица 2x2)
    for page_idx in range(0, len(passports), 4):
        passport_group = passports[page_idx:page_idx+4]
        
        # Создаем таблицу 2x2 (2 строки, 2 колонки) = 4 наклейки на странице
        table = doc.add_table(rows=2, cols=2)
        table.style = None
        
        # Настраиваем таблицу
        tbl = table._tbl
        tblPr = tbl.tblPr
        if tblPr is None:
            tblPr = OxmlElement('w:tblPr')
            tbl.insert(0, tblPr)
        
        # Устанавливаем ширину таблицы
        total_table_width = sticker_width_mm * 2
        tblWidth = OxmlElement('w:tblW')
        tblWidth.set(qn('w:w'), str(int(total_table_width * 56.7)))
        tblWidth.set(qn('w:type'), 'dxa')
        tblPr.append(tblWidth)
        
        # Устанавливаем ширину колонок
        tblGrid = OxmlElement('w:tblGrid')
        for col_idx in range(2):
            gridCol = OxmlElement('w:gridCol')
            gridCol.set(qn('w:w'), str(int(sticker_width_mm * 56.7)))
            tblGrid.append(gridCol)
        tbl.append(tblGrid)
        
        # Убираем границы таблицы
        tblBorders = OxmlElement('w:tblBorders')
        for border_name in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']:
            border = OxmlElement(f'w:{border_name}')
            border.set(qn('w:val'), 'nil')
            border.set(qn('w:sz'), '0')
            border.set(qn('w:space'), '0')
            border.set(qn('w:color'), 'auto')
            tblBorders.append(border)
        tblPr.append(tblBorders)
        
        # Убираем отступы таблицы
        tblCellMar = OxmlElement('w:tblCellMar')
        for margin_name in ['top', 'left', 'bottom', 'right']:
            margin = OxmlElement(f'w:{margin_name}')
            margin.set(qn('w:w'), '0')
            margin.set(qn('w:type'), 'dxa')
            tblCellMar.append(margin)
        tblPr.append(tblCellMar)
        
        # Настраиваем ячейки
        for row_idx in range(4):
            for col_idx in range(2):
                cell = table.rows[row_idx].cells[col_idx]
                tcPr = cell._element.tcPr
                if tcPr is None:
                    tcPr = OxmlElement('w:tcPr')
                    cell._element.insert(0, tcPr)
                
                # Устанавливаем ширину ячейки
                tcW = tcPr.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}tcW')
                if tcW is None:
                    tcW = OxmlElement('w:tcW')
                    tcPr.append(tcW)
                tcW.set(qn('w:w'), str(int(sticker_width_mm * 56.7)))
                tcW.set(qn('w:type'), 'dxa')
                
                # Убираем отступы
                tcMar = OxmlElement('w:tcMar')
                for margin_name in ['top', 'left', 'bottom', 'right']:
                    margin = OxmlElement(f'w:{margin_name}')
                    margin.set(qn('w:w'), '0')
                    margin.set(qn('w:type'), 'dxa')
                    tcMar.append(margin)
                tcPr.append(tcMar)
                
                # Устанавливаем высоту строки
                tr = cell._element.getparent()
                trPr = tr.trPr
                if trPr is None:
                    trPr = OxmlElement('w:trPr')
                    tr.insert(0, trPr)
                trHeight = OxmlElement('w:trHeight')
                trHeight.set(qn('w:val'), str(int(sticker_height_mm * 20)))
                trHeight.set(qn('w:hRule'), 'exact')
                trPr.append(trHeight)
                
                # Вертикальное выравнивание
                vAlign = tcPr.find('.//{http://schemas.openxmlformats.org/wordprocessingml/2006/main}vAlign')
                if vAlign is None:
                    vAlign = OxmlElement('w:vAlign')
                    tcPr.append(vAlign)
                vAlign.set(qn('w:val'), 'top')
        
        # Заполняем таблицу наклейками
        print(f"📄 Страница {page_idx // 4 + 1}: заполняем таблицу 2x2 (4 наклейки)")
        sys.stdout.flush()
        
        for row_idx in range(4):
            for col_idx in range(2):
                idx = row_idx * 2 + col_idx
                cell = table.rows[row_idx].cells[col_idx]
                
                if idx < len(passport_group):
                    passport = passport_group[idx]
                    nomenclature = passport.nomenclature
                    
                    if not nomenclature:
                        print(f"⚠️ Нет номенклатуры для паспорта {passport.passport_number}")
                        continue
                    
                    # Получаем дату производства
                    production_date = "2025"
                    if passport.created_at:
                        production_date = passport.created_at.strftime("%Y")
                    
                    print(f"  📋 Наклейка [{row_idx}][{col_idx}]: {passport.passport_number}")
                    sys.stdout.flush()
                    
                    try:
                        # ПРОСТОЙ АЛГОРИТМ: рендерим шаблон и копируем содержимое
                        success = render_template_to_cell(
                            template_path,
                            cell,
                            doc,
                            passport,
                            nomenclature,
                            production_date,
                            logo_path
                        )
                        if success:
                            print(f"    ✅ Наклейка создана")
                        else:
                            print(f"    ⚠️ Ошибка создания наклейки")
                    except Exception as e:
                        print(f"    ❌ Ошибка: {e}")
                        import traceback
                        traceback.print_exc()
        
        # Добавляем разрыв страницы (кроме последней)
        if page_idx + 8 < len(passports):
            doc.add_page_break()
    
    # Сохраняем в память
    buffer = io.BytesIO()
    doc.save(buffer)
    buffer.seek(0)
    docx_content = buffer.getvalue()
    
    print(f"✅ DOCX с наклейками успешно сгенерирован, размер: {len(docx_content)} байт")
    sys.stdout.flush()
    
    return docx_content


def render_template_to_cell(template_path, target_cell, target_doc, passport, nomenclature, production_date, logo_path):
    """
    ПРОСТОЙ И ПРАВИЛЬНЫЙ АЛГОРИТМ:
    1. Берем шаблон из backend/utils/templates/sticker_template.docx
    2. Генерируем штрихкоды для артикула и серийного номера
    3. Заполняем шаблон через docxtpl
    4. Копируем ВСЁ содержимое ячейки из рендеренного шаблона в целевую ячейку
    """
    try:
        from backend.utils.barcode_generator import generate_barcode_image
        import tempfile
        import shutil
        import zipfile
        import re
        
        print(f"    🔄 Рендерим шаблон для {passport.passport_number}...")
        
        # 1. Создаем копию шаблона
        with tempfile.NamedTemporaryFile(suffix='.docx', delete=False) as tmp_file:
            temp_template_path = tmp_file.name
            shutil.copy(template_path, temp_template_path)
        
        # 2. КРИТИЧНО: Исправляем проблемные плейсхолдеры ДО первого рендеринга
        # Это должно быть сделано ДО создания DocxTemplate
        try:
            with zipfile.ZipFile(temp_template_path, 'r') as zip_file:
                doc_xml = zip_file.read('word/document.xml')
                xml_str = doc_xml.decode('utf-8')
                
                # АГРЕССИВНОЕ исправление: удаляем ВСЕ проблемные конструкции
                fixed_xml = xml_str
                
                # 1. Удаляем .size из любых мест (включая внутри плейсхолдеров)
                fixed_xml = re.sub(r'\.size', '', fixed_xml)
                
                # 2. Удаляем проблемные фильтры Jinja2
                fixed_xml = re.sub(r'\|\s*\w+\([^)]*\)', '', fixed_xml)
                fixed_xml = re.sub(r'\|\s*\w+', '', fixed_xml)
                
                # 3. Исправляем разорванные плейсхолдеры - объединяем содержимое между {{ и }}
                # Ищем паттерны вида {{...<w:t>текст</w:t>...}} и заменяем на {{...текст...}}
                # Но делаем это аккуратно, не ломая XML структуру
                # Просто удаляем XML-теги внутри плейсхолдеров, сохраняя текст
                for _ in range(3):  # Повторяем несколько раз для вложенных тегов
                    # Ищем {{...<w:t>текст</w:t>...}} и заменяем на {{...текст...}}
                    fixed_xml = re.sub(r'(\{\{[^<]*?)(<w:t[^>]*>)([^<]*?)(</w:t>)([^}]*?\}\})', r'\1\3\5', fixed_xml)
                    fixed_xml = re.sub(r'(\{\{[^<]*?)(<w:rPr[^>]*>)([^<]*?)(</w:rPr>)([^}]*?\}\})', r'\1\5', fixed_xml)
                
                if fixed_xml != xml_str:
                    fixed_zip_path = temp_template_path + '.fixed'
                    with zipfile.ZipFile(fixed_zip_path, 'w', zipfile.ZIP_DEFLATED) as new_zip:
                        for item in zip_file.infolist():
                            if item.filename == 'word/document.xml':
                                new_zip.writestr(item, fixed_xml)
                            else:
                                new_zip.writestr(item, zip_file.read(item.filename))
                    
                    shutil.move(fixed_zip_path, temp_template_path)
                    print(f"    ✅ Шаблон исправлен (удалены проблемные конструкции)")
        except Exception as fix_err:
            print(f"    ⚠️ Ошибка исправления шаблона: {fix_err}")
            import traceback
            traceback.print_exc()
        
        # 3. Генерируем штрихкоды
        stock_code = nomenclature.article or getattr(nomenclature, 'code_1c', None) or '3501040'
        stock_code_barcode_path = generate_barcode_image(stock_code, width_mm=40, height_mm=10)
        
        serial_number = passport.passport_number or 'AGB0000125'
        serial_number_barcode_path = generate_barcode_image(serial_number, width_mm=40, height_mm=10)
        
        print(f"    📷 Штрихкоды сгенерированы: {stock_code}, {serial_number}")
        
        # 4. Загружаем шаблон ПОСЛЕ исправления
        template = DocxTemplate(temp_template_path)
        
        # Получаем данные из номенклатуры и паспорта
        context = {
            'nomenclature_name': nomenclature.name or 'Буровой инструмент',
            'article': nomenclature.article or getattr(nomenclature, 'code_1c', None) or '3501040',
            'matrix': nomenclature.matrix or 'NQ',
            'serial_number': passport.passport_number or 'AGB 3-5 NQ 0000125',
            'serial number': passport.passport_number or 'AGB 3-5 NQ 0000125',  # С пробелом
            'waterways': getattr(nomenclature, 'waterways', None) or '8',
            'production_date': production_date,
            'date': production_date,
            'company_name_ru': 'ООО "Алмазгеобур"',
            'company_name_en': 'LLP "Almazgeobur"',
            'website': 'www.almazgeobur.ru',
            'height': nomenclature.height or getattr(nomenclature, 'drilling_depth', None) or '12',
            'tool size': nomenclature.matrix or 'NQ',
            'order_number': getattr(passport, 'order_number', None) or '',
        }
        
        print(f"    📋 Данные для шаблона:")
        print(f"      - nomenclature_name: {context['nomenclature_name']}")
        print(f"      - article: {context['article']}")
        print(f"      - matrix: {context['matrix']}")
        print(f"      - serial_number: {context['serial_number']}")
        print(f"      - height: {context['height']}")
        print(f"      - waterways: {context['waterways']}")
        
        # 5. Добавляем изображения в контекст
        if logo_path and os.path.exists(logo_path):
            try:
                context['logo'] = InlineImage(template, logo_path, width=DocxMm(18), height=DocxMm(5.4))
                print(f"    ✅ Логотип добавлен в контекст: {logo_path}")
            except Exception as e:
                print(f"    ⚠️ Ошибка добавления логотипа: {e}")
                import traceback
                traceback.print_exc()
                context['logo'] = None
        else:
            print(f"    ⚠️ Логотип не найден: {logo_path}")
            context['logo'] = None
        
        if stock_code_barcode_path and os.path.exists(stock_code_barcode_path):
            try:
                context['stock_code'] = InlineImage(template, stock_code_barcode_path, width=DocxMm(40), height=DocxMm(10))
                print(f"    ✅ Штрихкод stock_code добавлен в контекст: {stock_code}")
            except Exception as e:
                print(f"    ⚠️ Ошибка добавления штрихкода stock_code: {e}")
                import traceback
                traceback.print_exc()
                context['stock_code'] = stock_code
        else:
            print(f"    ⚠️ Штрихкод stock_code не сгенерирован, используем текст: {stock_code}")
            context['stock_code'] = stock_code
        
        if serial_number_barcode_path and os.path.exists(serial_number_barcode_path):
            try:
                context['serial_number_code'] = InlineImage(template, serial_number_barcode_path, width=DocxMm(40), height=DocxMm(10))
                print(f"    ✅ Штрихкод serial_number_code добавлен в контекст: {serial_number}")
            except Exception as e:
                print(f"    ⚠️ Ошибка добавления штрихкода serial_number_code: {e}")
                import traceback
                traceback.print_exc()
                context['serial_number_code'] = serial_number
        else:
            print(f"    ⚠️ Штрихкод serial_number_code не сгенерирован, используем текст: {serial_number}")
            context['serial_number_code'] = serial_number
        
        # 6. Рендерим шаблон
        render_success = False
        try:
            template.render(context)
            print(f"    ✅ Шаблон отрендерен успешно")
            render_success = True
        except Exception as render_err:
            error_str = str(render_err)
            print(f"    ⚠️ Ошибка рендеринга: {error_str}")
            import traceback
            traceback.print_exc()
            
            # Пробуем еще раз с более агрессивным исправлением
            try:
                print(f"    🔄 Пробуем более агрессивное исправление шаблона...")
                with zipfile.ZipFile(temp_template_path, 'r') as zip_file:
                    doc_xml = zip_file.read('word/document.xml')
                    xml_str = doc_xml.decode('utf-8')
                    
                    # Еще более агрессивное исправление
                    fixed_xml = xml_str
                    # Удаляем все .size
                    fixed_xml = re.sub(r'\.size', '', fixed_xml)
                    # Удаляем все фильтры
                    fixed_xml = re.sub(r'\|\s*\w+\([^)]*\)', '', fixed_xml)
                    fixed_xml = re.sub(r'\|\s*\w+', '', fixed_xml)
                    
                    if fixed_xml != xml_str:
                        fixed_zip_path = temp_template_path + '.fixed2'
                        with zipfile.ZipFile(fixed_zip_path, 'w', zipfile.ZIP_DEFLATED) as new_zip:
                            for item in zip_file.infolist():
                                if item.filename == 'word/document.xml':
                                    new_zip.writestr(item, fixed_xml)
                                else:
                                    new_zip.writestr(item, zip_file.read(item.filename))
                        shutil.move(fixed_zip_path, temp_template_path)
                        template = DocxTemplate(temp_template_path)
                        # Обновляем изображения в контексте
                        if logo_path and os.path.exists(logo_path):
                            context['logo'] = InlineImage(template, logo_path, width=DocxMm(18), height=DocxMm(5.4))
                        if stock_code_barcode_path and os.path.exists(stock_code_barcode_path):
                            context['stock_code'] = InlineImage(template, stock_code_barcode_path, width=DocxMm(40), height=DocxMm(10))
                        if serial_number_barcode_path and os.path.exists(serial_number_barcode_path):
                            context['serial_number_code'] = InlineImage(template, serial_number_barcode_path, width=DocxMm(40), height=DocxMm(10))
                        
                        # Пробуем рендерить снова
                        try:
                            template.render(context)
                            print(f"    ✅ Шаблон отрендерен после исправления")
                            render_success = True
                        except Exception as render_err2:
                            print(f"    ⚠️ Повторный рендеринг тоже не удался: {render_err2}")
                            # Продолжаем с неотрендеренным шаблоном
            except Exception as retry_err:
                print(f"    ⚠️ Повторная попытка исправления не удалась: {retry_err}")
                # Продолжаем с неотрендеренным шаблоном
        
        if not render_success:
            print(f"    ⚠️ ВНИМАНИЕ: Шаблон не был отрендерен, данные могут быть не заполнены!")
            # Если рендеринг не работает, заполняем данные вручную в XML
            try:
                print(f"    🔄 Пробуем заполнить данные вручную в XML...")
                with zipfile.ZipFile(temp_template_path, 'r') as zip_file:
                    doc_xml = zip_file.read('word/document.xml')
                    xml_str = doc_xml.decode('utf-8')
                    
                    # Заменяем плейсхолдеры на данные
                    replacements = {
                        '{{nomenclature_name}}': context.get('nomenclature_name', ''),
                        '{{article}}': context.get('article', ''),
                        '{{matrix}}': context.get('matrix', ''),
                        '{{serial_number}}': context.get('serial_number', ''),
                        '{{serial number}}': context.get('serial number', ''),
                        '{{waterways}}': context.get('waterways', ''),
                        '{{production_date}}': context.get('production_date', ''),
                        '{{date}}': context.get('date', ''),
                        '{{height}}': context.get('height', ''),
                        '{{tool size}}': context.get('tool size', ''),
                    }
                    
                    for placeholder, value in replacements.items():
                        xml_str = xml_str.replace(placeholder, str(value))
                    
                    # Сохраняем исправленный XML
                    fixed_zip_path = temp_template_path + '.manual_fixed'
                    with zipfile.ZipFile(fixed_zip_path, 'w', zipfile.ZIP_DEFLATED) as new_zip:
                        for item in zip_file.infolist():
                            if item.filename == 'word/document.xml':
                                new_zip.writestr(item, xml_str)
                            else:
                                new_zip.writestr(item, zip_file.read(item.filename))
                    shutil.move(fixed_zip_path, temp_template_path)
                    template = DocxTemplate(temp_template_path)
                    print(f"    ✅ Данные заполнены вручную в XML")
            except Exception as manual_err:
                print(f"    ⚠️ Ошибка ручного заполнения данных: {manual_err}")
        
        # 7. Сохраняем рендеренный шаблон
        rendered_path = temp_template_path.replace('.docx', '_rendered.docx')
        template.save(rendered_path)
        
        # 8. Загружаем рендеренный документ
        try:
            rendered_doc = Document(rendered_path)
        except Exception as load_err:
            print(f"    ❌ Ошибка загрузки рендеренного документа: {load_err}")
            import traceback
            traceback.print_exc()
            return False
        
        if not rendered_doc.tables or len(rendered_doc.tables) == 0:
            print(f"    ❌ Рендеренный шаблон не содержит таблицы")
            return False
        
        rendered_table = rendered_doc.tables[0]
        if len(rendered_table.rows) == 0 or len(rendered_table.rows[0].cells) == 0:
            print(f"    ❌ Рендеренный шаблон не содержит ячейки")
            return False
        
        source_cell = rendered_table.rows[0].cells[0]
        
        # Убеждаемся, что это объекты, а не строки
        if not hasattr(rendered_doc, 'part'):
            print(f"    ❌ rendered_doc не имеет атрибута part")
            return False
        source_part = rendered_doc.part
        
        if not hasattr(target_doc, 'part'):
            print(f"    ❌ target_doc не имеет атрибута part")
            return False
        target_part = target_doc.part
        
        # Проверяем, что это правильные объекты
        if not hasattr(source_part, 'rels'):
            print(f"    ❌ source_part не имеет атрибута rels: {type(source_part)}")
            return False
        if not hasattr(target_part, 'rels'):
            print(f"    ❌ target_part не имеет атрибута rels: {type(target_part)}")
            return False
        
        # 9. Копируем ВСЁ содержимое ячейки из рендеренного шаблона
        # Очищаем целевую ячейку
        for child in list(target_cell._element):
            if not child.tag.endswith('}tcPr'):
                target_cell._element.remove(child)
        
        # Собираем все элементы ячейки (кроме tcPr)
        source_content = []
        for child in source_cell._element:
            if not child.tag.endswith('}tcPr'):
                element_xml_str = ET.tostring(child, encoding='unicode')
                element_xml = ET.fromstring(element_xml_str)
                source_content.append((child.tag, element_xml))
        
        print(f"    📋 Найдено {len(source_content)} элементов для копирования")
        
        # Вставляем все элементы в целевую ячейку с обработкой изображений
        images_copied = 0
        
        # Сначала обрабатываем все изображения во всех элементах
        for tag, element_xml in source_content:
            all_drawings = element_xml.findall('.//{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}inline')
            if len(all_drawings) > 0:
                print(f"    🔍 В элементе {tag.split('}')[-1]}: найдено {len(all_drawings)} изображений")
            
            for drawing in all_drawings:
                blip = drawing.find('.//{http://schemas.openxmlformats.org/drawingml/2006/main}blip')
                if blip is not None:
                    embed_id = blip.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed')
                    if embed_id:
                        # Проверяем relationships напрямую
                        if embed_id in source_part.rels:
                            try:
                                image_rel = source_part.rels[embed_id]
                                # Проверяем, что это действительно изображение
                                if hasattr(image_rel, 'target_part') and hasattr(image_rel.target_part, 'blob'):
                                    image_blob = image_rel.target_part.blob
                                    # Добавляем изображение в целевой документ через правильный API
                                    try:
                                        # relate_to требует файл, а не BytesIO - создаем временный файл
                                        with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as tmp_img:
                                            tmp_img.write(image_blob)
                                            tmp_img_path = tmp_img.name
                                        
                                        # Используем relate_to с файлом
                                        rId = target_part.relate_to(tmp_img_path, 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image', is_external=False)
                                        new_embed_id = rId
                                        
                                        # Удаляем временный файл
                                        try:
                                            os.unlink(tmp_img_path)
                                        except:
                                            pass
                                    except Exception as add_img_err:
                                        print(f"    ⚠️ Ошибка добавления изображения: {add_img_err}")
                                        import traceback
                                        traceback.print_exc()
                                        continue
                                    # Обновляем embed_id в XML
                                    blip.set('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed', new_embed_id)
                                    images_copied += 1
                                    print(f"    ✅ Изображение {images_copied} скопировано (embed_id: {embed_id} -> {new_embed_id})")
                                else:
                                    print(f"    ⚠️ Relationship {embed_id} не содержит изображение")
                            except Exception as img_err:
                                print(f"    ⚠️ Ошибка копирования изображения {embed_id}: {img_err}")
                                import traceback
                                traceback.print_exc()
                        else:
                            # Пробуем найти изображение по содержимому relationships
                            found = False
                            if not hasattr(source_part, 'rels'):
                                print(f"    ⚠️ source_part не имеет rels: {type(source_part)}")
                                continue
                            for rel_id, rel in source_part.rels.items():
                                try:
                                    if hasattr(rel, 'target_part') and hasattr(rel.target_part, 'content_type'):
                                        if 'image' in rel.target_part.content_type or 'png' in rel.target_part.content_type or 'jpeg' in rel.target_part.content_type:
                                            # Проверяем размер - если похож на наше изображение
                                            if hasattr(rel.target_part, 'blob'):
                                                image_blob = rel.target_part.blob
                                                if len(image_blob) > 100:  # Минимальный размер изображения
                                                    try:
                                                        # relate_to требует файл, а не BytesIO - создаем временный файл
                                                        with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as tmp_img:
                                                            tmp_img.write(image_blob)
                                                            tmp_img_path = tmp_img.name
                                                        
                                                        # Используем relate_to с файлом
                                                        rId = target_part.relate_to(tmp_img_path, 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image', is_external=False)
                                                        new_embed_id = rId
                                                        
                                                        # Удаляем временный файл
                                                        try:
                                                            os.unlink(tmp_img_path)
                                                        except:
                                                            pass
                                                    except Exception as add_img_err:
                                                        print(f"    ⚠️ Ошибка добавления изображения: {add_img_err}")
                                                        continue
                                                    blip.set('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed', new_embed_id)
                                                    images_copied += 1
                                                    print(f"    ✅ Изображение {images_copied} найдено и скопировано (rel_id: {rel_id})")
                                                    found = True
                                                    break
                                except:
                                    pass
                            
                            if not found:
                                print(f"    ⚠️ embed_id {embed_id} не найден в relationships")
        
        # Теперь копируем все элементы с уже обработанными изображениями
        for tag, element_xml in source_content:
            try:
                element_xml_str = ET.tostring(element_xml, encoding='unicode')
                copied_element = parse_xml(element_xml_str)
                target_cell._element.append(copied_element)
                element_name = tag.split('}')[-1] if '}' in tag else tag
                print(f"    ✅ Элемент {element_name} скопирован")
            except Exception as append_err:
                print(f"    ⚠️ Ошибка копирования элемента {tag}: {append_err}")
                import traceback
                traceback.print_exc()
        
        print(f"    ✅ Содержимое скопировано: {len(source_content)} элементов, {images_copied} изображений")
        
        # Удаляем временные файлы
        try:
            os.unlink(temp_template_path)
            os.unlink(rendered_path)
            if stock_code_barcode_path and os.path.exists(stock_code_barcode_path):
                os.unlink(stock_code_barcode_path)
            if serial_number_barcode_path and os.path.exists(serial_number_barcode_path):
                os.unlink(serial_number_barcode_path)
        except:
            pass
        
        return True
        
    except Exception as e:
        print(f"    ❌ Ошибка при рендеринге шаблона: {e}")
        import traceback
        traceback.print_exc()
        return False


# Стандартный метод генерации (fallback)
def generate_stickers_standard(passports):
    """Стандартный метод генерации наклеек без шаблона"""
    print(f"🔄 Используем стандартный метод генерации для {len(passports)} паспортов")
    sys.stdout.flush()
    
    # Создаем простой документ
    doc = Document()
    section = doc.sections[0]
    section.page_height = Mm(297)
    section.page_width = Mm(210)
    
    # Группируем по 8 на страницу
    for page_idx in range(0, len(passports), 4):
        passport_group = passports[page_idx:page_idx+4]
        table = doc.add_table(rows=4, cols=2)
        
        for row_idx in range(4):
            for col_idx in range(2):
                idx = row_idx * 2 + col_idx
                cell = table.rows[row_idx].cells[col_idx]
                
                if idx < len(passport_group):
                    passport = passport_group[idx]
                    nomenclature = passport.nomenclature
                    if nomenclature:
                        cell.text = f"{nomenclature.name}\n{passport.passport_number}"
        
        if page_idx + 8 < len(passports):
            doc.add_page_break()
    
    buffer = io.BytesIO()
    doc.save(buffer)
    buffer.seek(0)
    return buffer.getvalue()

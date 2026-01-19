"""
Генератор наклеек из шаблона Word с плейсхолдерами
"""
import os
import io
from typing import List
from docxtpl import DocxTemplate
from docx.shared import Mm


def get_template_path():
    """Получает путь к шаблону наклеек"""
    # Получаем абсолютный путь к директории модуля
    current_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(os.path.dirname(current_dir))
    
    # Проверяем несколько возможных путей
    possible_paths = [
        os.path.join(current_dir, 'templates', 'sticker_template.docx'),  # backend/utils/templates/sticker_template.docx
        os.path.join(project_root, 'templates', 'sticker_template.docx'),  # /root/agb_passports/templates/sticker_template.docx
        os.path.join(project_root, 'backend', 'utils', 'templates', 'sticker_template.docx'),
        '/app/backend/utils/templates/sticker_template.docx',  # Путь внутри Docker контейнера
        '/app/templates/sticker_template.docx',  # Альтернативный путь в контейнере
        'templates/sticker_template.docx',
        './templates/sticker_template.docx',
    ]
    
    for template_path in possible_paths:
        abs_path = os.path.abspath(template_path)
        if os.path.exists(abs_path):
            print(f"✅ Шаблон найден: {abs_path}")
            return abs_path
    
    print("⚠️ Шаблон не найден, будет использован стандартный метод генерации")
    return None


def generate_stickers_from_template(passports, template_path=None):
    """
    Генерирует DOCX с наклейками из шаблона Word
    
    Шаблон должен содержать плейсхолдеры в формате Jinja2:
    - {{ logo }} - для логотипа (изображение)
    - {{ company_name_ru }} - название компании на русском
    - {{ company_name_en }} - название компании на английском
    - {{ nomenclature_name }} - название номенклатуры
    - {{ article }} - артикул
    - {{ matrix }} - типоразмер
    - {{ height }} - высота матрицы
    - {{ waterways }} - промывочные отверстия
    - {{ serial_number }} - серийный номер
    - {{ production_date }} - дата производства
    - {{ order_number }} - номер заказа
    """
    from docx import Document
    from docx.shared import Mm, Pt
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.oxml.ns import qn
    from docx.oxml import OxmlElement
    
    print(f"🏷️ Начинаем генерацию DOCX наклеек из шаблона для {len(passports)} паспортов")
    
    # Пытаемся использовать шаблон
    if template_path is None:
        template_path = get_template_path()
    
    if template_path and os.path.exists(template_path):
        try:
            return generate_from_template_file(passports, template_path)
        except Exception as e:
            print(f"⚠️ Ошибка при использовании шаблона: {e}")
            import traceback
            traceback.print_exc()
            print("🔄 Переключаемся на стандартный метод генерации...")
    
    # Fallback: стандартный метод генерации
    return generate_stickers_standard(passports)


def generate_from_template_file(passports, template_path):
    """Генерирует наклейки из файла шаблона Word
    
    Шаблон должен содержать одну наклейку с плейсхолдерами.
    Система автоматически разместит 8 наклеек на странице (2 ряда по 4).
    """
    from docx import Document
    from docx.shared import Mm
    from docx.oxml import OxmlElement
    from docx.oxml.ns import qn
    import os
    import shutil
    
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
    
    # Размеры наклейки: 52.5 x 148.5 mm (2 ряда по 4 наклейки)
    sticker_width = Mm(52.5)
    sticker_height = Mm(148.5)
    
    # Получаем путь к логотипу
    logo_path = None
    try:
        from backend.utils.pdf_generator import create_logo_image
        logo_path = create_logo_image()
        if not logo_path or not os.path.exists(logo_path):
            logo_path = None
    except:
        pass
    
    # Группируем паспорта по 8 на страницу
    for page_idx in range(0, len(passports), 8):
        passport_group = passports[page_idx:page_idx+8]
        
        # Создаем таблицу 2x4 для размещения наклеек
        table = doc.add_table(rows=2, cols=4)
        table.style = None
        
        # Настраиваем таблицу
        tbl = table._tbl
        tblPr = tbl.tblPr
        if tblPr is None:
            tblPr = OxmlElement('w:tblPr')
            tbl.insert(0, tblPr)
        
        # Устанавливаем ширину колонок и убираем отступы
        for row_idx in range(2):
            for col_idx in range(4):
                cell = table.rows[row_idx].cells[col_idx]
                cell.width = sticker_width
                
                # Убираем все отступы в ячейках
                tcPr = cell._element.tcPr
                if tcPr is None:
                    tcPr = OxmlElement('w:tcPr')
                    cell._element.insert(0, tcPr)
                
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
                trHeight.set(qn('w:val'), str(int(sticker_height * 20)))
                trHeight.set(qn('w:hRule'), 'exact')
                trPr.append(trHeight)
        
        # Заполняем таблицу наклейками из шаблона
        for row_idx in range(2):
            for col_idx in range(4):
                idx = row_idx * 4 + col_idx
                cell = table.rows[row_idx].cells[col_idx]
                
                if idx < len(passport_group):
                    passport = passport_group[idx]
                    nomenclature = passport.nomenclature
                    
                    if not nomenclature:
                        continue
                    
                    # Получаем дату производства
                    production_date = "2025"
                    if passport.created_at:
                        production_date = passport.created_at.strftime("%Y")
                    
                    # Загружаем и рендерим шаблон для одной наклейки
                    try:
                        # Создаем временный файл для рендеринга
                        import tempfile
                        with tempfile.NamedTemporaryFile(suffix='.docx', delete=False) as tmp_file:
                            tmp_path = tmp_file.name
                            shutil.copy(template_path, tmp_path)
                        
                        template = DocxTemplate(tmp_path)
                        
                        # Подготавливаем данные для подстановки
                        context = {
                            'company_name_ru': 'ООО "Алмазгеобур"',
                            'company_name_en': 'LLP "Almazgeobur"',
                            'nomenclature_name': nomenclature.name or 'Буровой инструмент',
                            'article': nomenclature.article or '3501040',
                            'matrix': nomenclature.matrix or 'NQ',
                            'height': nomenclature.height or '12',
                            'waterways': '8',
                            'serial_number': passport.passport_number or 'AGB 3-5 NQ 0000125',
                            'production_date': production_date,
                            'order_number': getattr(passport, 'order_number', '') or '',
                        }
                        
                        # Добавляем логотип если доступен
                        if logo_path:
                            context['logo'] = logo_path
                        
                        # Рендерим шаблон
                        template.render(context)
                        
                        # Копируем содержимое из шаблона в ячейку
                        # Очищаем ячейку
                        cell.text = ''
                        while len(cell.paragraphs) > 1:
                            p = cell.paragraphs[-1]
                            p._element.getparent().remove(p._element)
                        
                        # Копируем все параграфы из шаблона
                        source_paras = template.docx.paragraphs
                        if source_paras:
                            # Очищаем первый параграф ячейки
                            target_para = cell.paragraphs[0]
                            target_para.clear()
                            
                            # Копируем содержимое первого параграфа шаблона
                            for run in source_paras[0].runs:
                                new_run = target_para.add_run(run.text)
                                if run.font.size:
                                    new_run.font.size = run.font.size
                                new_run.font.bold = run.font.bold
                                new_run.font.italic = run.font.italic
                            
                            # Копируем остальные параграфы
                            for para in source_paras[1:]:
                                new_para = cell.add_paragraph()
                                for run in para.runs:
                                    new_run = new_para.add_run(run.text)
                                    if run.font.size:
                                        new_run.font.size = run.font.size
                                    new_run.font.bold = run.font.bold
                                    new_run.font.italic = run.font.italic
                        
                        # Удаляем временный файл
                        try:
                            os.unlink(tmp_path)
                        except:
                            pass
                        
                        print(f"✅ Наклейка {passport.passport_number} создана из шаблона")
                        
                    except Exception as e:
                        print(f"⚠️ Ошибка при рендеринге шаблона для {passport.passport_number}: {e}")
                        import traceback
                        traceback.print_exc()
                        # Fallback: используем стандартный метод
                        fill_cell_standard(cell, passport, nomenclature, production_date)
        
        # Добавляем разрыв страницы (кроме последней)
        if page_idx + 8 < len(passports):
            doc.add_page_break()
    
    # Сохраняем в память
    buffer = io.BytesIO()
    doc.save(buffer)
    buffer.seek(0)
    
    docx_content = buffer.getvalue()
    print(f"✅ DOCX с наклейками из шаблона успешно сгенерирован, размер: {len(docx_content)} байт")
    
    return docx_content


def fill_cell_standard(cell, passport, nomenclature, production_date):
    """Заполняет ячейку стандартным способом (fallback)"""
    from docx.shared import Pt
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.oxml import OxmlElement
    from docx.oxml.ns import qn
    import os
    
    # Очищаем ячейку
    cell.text = ''
    while len(cell.paragraphs) > 1:
        p = cell.paragraphs[-1]
        p._element.getparent().remove(p._element)
    
    p = cell.paragraphs[0]
    p.clear()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    
    # Убираем отступы
    pPr = p._element.get_or_add_pPr()
    spacing = OxmlElement('w:spacing')
    spacing.set(qn('w:before'), '0')
    spacing.set(qn('w:after'), '0')
    spacing.set(qn('w:line'), '200')
    spacing.set(qn('w:lineRule'), 'auto')
    pPr.append(spacing)
    
    ind = OxmlElement('w:ind')
    ind.set(qn('w:left'), '0')
    ind.set(qn('w:right'), '0')
    ind.set(qn('w:firstLine'), '0')
    pPr.append(ind)
    
    # Добавляем логотип
    try:
        from backend.utils.pdf_generator import create_logo_image
        logo_img = create_logo_image()
        if logo_img and os.path.exists(logo_img):
            run = p.add_run()
            run.add_picture(logo_img, width=Mm(18), height=Mm(5.4))
            run.add_break()
    except:
        pass
    
    # Добавляем данные
    run = p.add_run(f"{nomenclature.name or 'Буровой инструмент'}\n")
    run.font.size = Pt(5)
    run.font.bold = True
    
    run = p.add_run(f"Артикул / Stock Code: {nomenclature.article or '3501040'}\n")
    run.font.size = Pt(4)
    run = p.add_run(f"Типоразмер / Tool size: {nomenclature.matrix or 'NQ'}\n")
    run.font.size = Pt(4)
    run = p.add_run(f"Высота матрицы / Imp Depth: {nomenclature.height or '12'} мм\n")
    run.font.size = Pt(4)
    run = p.add_run(f"Промывочные отверстия / Waterways: 8 mm\n")
    run.font.size = Pt(4)
    run = p.add_run(f"Серийный номер / Serial Number: {passport.passport_number or 'AGB 3-5 NQ 0000125'}\n")
    run.font.size = Pt(4)
    run.font.bold = True
    run = p.add_run(f"Дата производства / Production date: {production_date}\n")
    run.font.size = Pt(4)


def generate_stickers_standard(passports):
    """Стандартный метод генерации наклеек (без шаблона)"""
    from backend.utils.pdf_generator import generate_stickers_docx
    return generate_stickers_docx(passports)

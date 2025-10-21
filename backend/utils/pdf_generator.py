"""
Генератор PDF для паспортов коронок
"""

from reportlab.lib.pagesizes import A4
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, Image
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_CENTER, TA_LEFT
import io
import os

def create_logo_image():
    """Создание изображения логотипа"""
    try:
        # Попытка загрузить логотип из файла
        logo_path = os.path.join(os.path.dirname(__file__), "..", "static", "logo.png")
        if os.path.exists(logo_path):
            return logo_path
    except Exception as e:
        print(f"Ошибка загрузки логотипа: {e}")
    return None

def create_passport_styles(normal_font):
    """Создание стилей для паспорта"""
    styles = getSampleStyleSheet()
    
    # Стиль заголовка
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontName=normal_font,
        fontSize=16,
        spaceAfter=12,
        alignment=TA_CENTER,
        textColor=colors.black
    )
    
    # Стиль подзаголовка
    subtitle_style = ParagraphStyle(
        'CustomSubtitle',
        parent=styles['Heading2'],
        fontName=normal_font,
        fontSize=12,
        spaceAfter=8,
        alignment=TA_CENTER,
        textColor=colors.black
    )
    
    # Обычный стиль
    normal_style = ParagraphStyle(
        'CustomNormal',
        parent=styles['Normal'],
        fontName=normal_font,
        fontSize=10,
        spaceAfter=6,
        alignment=TA_LEFT,
        textColor=colors.black
    )
    
    return title_style, subtitle_style, normal_style

def create_passport_pdf_content(passport, normal_font, title_style, subtitle_style, normal_style):
    """Создание содержимого PDF паспорта"""
    story = []
    
    # Заголовок компании
    header_data = [
        ["", "ООО \"Алмазгеобур\"\n125362, г. Москва, улица Водников, дом 2, стр. 14, оф. 11\nтел.: +7 495 229 82 94\ne-mail: contact@almazgeobur.ru"]
    ]
    
    # Добавляем логотип
    logo_img = create_logo_image()
    if logo_img:
        logo_cell = Image(logo_img, width=40*mm, height=12*mm)
        header_data[0][0] = logo_cell
        header_table = Table(header_data, colWidths=[45*mm, 143*mm])
        header_table.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (-1, -1), normal_font),
            ('FONTSIZE', (0, 0), (-1, -1), 7),
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (0, 0), 'LEFT'),
            ('ALIGN', (1, 0), (1, 0), 'LEFT'),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('ENCODING', (0, 0), (-1, -1), 'utf-8'),
        ]))
    
    story.append(header_table)
    story.append(Spacer(1, 15))
    
    # Основная таблица с данными паспорта
    nomenclature = passport.nomenclature
    if not nomenclature:
        print(f"❌ Номенклатура не найдена для паспорта {passport.passport_number}")
        return story
    
    # Генерируем штрихкод
    barcode = f"AGB{nomenclature.article or '3501040'}-{passport.passport_number or '0000125'}"
    
    # Создаем стиль для переноса текста
    wrapped_style = ParagraphStyle(
        'WrappedText',
        parent=normal_style,
        fontSize=7,
        leading=9,
        spaceBefore=0,
        spaceAfter=0,
    )
    
    # Определяем тип продукта
    product_type = nomenclature.product_type or "коронка"
    product_type_ru = "Алмазная буровая коронка" if product_type == "коронка" else "Буровой инструмент"
    product_type_en = "Diamond drill bit" if product_type == "коронка" else "Drilling tool"
    
    # Создаем стиль для ячеек с переносом текста
    cell_style = ParagraphStyle(
        'CellText',
        parent=normal_style,
        fontSize=7,
        leading=9,
        spaceBefore=0,
        spaceAfter=0,
        alignment=TA_CENTER,
    )
    
    # Данные паспорта
    passport_data = [
        [Paragraph("Артикул / Stock Code", cell_style), 
         Paragraph("Типоразмер / Tool size", cell_style), 
         Paragraph("Серийный номер / Serial Number", cell_style), 
         Paragraph("Буровой инструмент / Tool type", cell_style)],
        [Paragraph(nomenclature.article or "3501040", cell_style), 
         Paragraph(nomenclature.matrix or "NQ", cell_style), 
         Paragraph(passport.passport_number or "AGB 3-5 NQ 0000125", cell_style), 
         Paragraph(f"{product_type_ru} / {product_type_en}", cell_style)],
        [Paragraph("Матрица / Matrix", cell_style), 
         Paragraph("Глубина бурения / Drilling depth", cell_style), 
         Paragraph("Высота / Height", cell_style), 
         Paragraph("Резьба / Thread", cell_style)],
        [Paragraph(nomenclature.matrix or "NQ", cell_style), 
         Paragraph(nomenclature.drilling_depth or "3-5", cell_style), 
         Paragraph(nomenclature.height or "50", cell_style), 
         Paragraph(nomenclature.thread or "NQ", cell_style)],
    ]
    
    # Создаем таблицу
    passport_table = Table(passport_data, colWidths=[47*mm, 47*mm, 47*mm, 47*mm])
    passport_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), normal_font),
        ('FONTSIZE', (0, 0), (-1, -1), 7),
        ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 1, colors.black),
        ('BACKGROUND', (0, 0), (-1, 0), colors.lightgrey),
        ('BACKGROUND', (0, 2), (-1, 2), colors.lightgrey),
        ('ENCODING', (0, 0), (-1, -1), 'utf-8'),
    ]))
    
    story.append(passport_table)
    story.append(Spacer(1, 20))
    
    # Добавляем информацию о штрихкоде
    barcode_text = Paragraph(f"Штрихкод / Barcode: {barcode}", normal_style)
    story.append(barcode_text)
    
    return story

def generate_bulk_passports_pdf(passports):
    """Генерация PDF для нескольких паспортов"""
    buffer = io.BytesIO()
    
    # Создаем документ
    doc = SimpleDocTemplate(buffer, pagesize=A4, topMargin=20*mm, bottomMargin=20*mm)
    
    # Получаем стили
    styles = getSampleStyleSheet()
    normal_font = "Helvetica"  # Используем стандартный шрифт
    
    title_style, subtitle_style, normal_style = create_passport_styles(normal_font)
    
    story = []
    
    for i, passport in enumerate(passports):
        if i > 0:
            # Добавляем разрыв страницы между паспортами
            story.append(Spacer(1, 20))
        
        # Создаем содержимое для каждого паспорта
        passport_content = create_passport_pdf_content(passport, normal_font, title_style, subtitle_style, normal_style)
        story.extend(passport_content)
    
    # Строим PDF
    doc.build(story)
    
    # Получаем PDF данные
    pdf_data = buffer.getvalue()
    buffer.close()
    
    return pdf_data

def generate_passport_pdf(passport):
    """Генерация PDF для одного паспорта"""
    return generate_bulk_passports_pdf([passport])

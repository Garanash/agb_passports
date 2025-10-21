import io
import os
from reportlab.lib.pagesizes import A4
from reportlab.platypus import SimpleDocTemplate, Paragraph, Table, TableStyle, Spacer, Image, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
# from cairosvg import svg2png  # Временно отключено для локальной разработки
from reportlab.lib.utils import ImageReader


def create_logo_image():
    """Создает изображение логотипа из PNG файла"""
    try:
        # Проверяем, существует ли файл logo.png в статической папке
        import os
        logo_path = os.path.join('static', 'logo.png')
        if os.path.exists(logo_path):
            return logo_path
        else:
            # Если файл не существует, создаем его
            from .create_logo import create_logo_png
            create_logo_png()
            if os.path.exists(logo_path):
                return logo_path
            else:
                print("Не удалось создать логотип")
                return None
    except Exception as e:
        print(f"Ошибка при загрузке логотипа: {e}")
        return None


def setup_cyrillic_fonts():
    """Настраивает шрифты с поддержкой кириллицы"""
    try:
        # Пробуем разные пути к шрифтам
        font_paths = [
            '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
            '/usr/share/fonts/TTF/DejaVuSans.ttf',
            '/usr/share/fonts/dejavu/DejaVuSans.ttf',
            '/System/Library/Fonts/Arial.ttf',  # macOS
            '/System/Library/Fonts/Helvetica.ttc',  # macOS
            '/Windows/Fonts/arial.ttf',  # Windows
            '/Windows/Fonts/calibri.ttf',  # Windows
            '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',  # Linux
            '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',  # Linux
        ]
        
        normal_font = 'Helvetica'
        for path in font_paths:
            try:
                if os.path.exists(path):
                    pdfmetrics.registerFont(TTFont('DejaVuSans', path))
                    normal_font = 'DejaVuSans'
                    print(f"✅ Успешно загружен шрифт: {path}")
                    break
            except Exception as e:
                print(f"❌ Ошибка загрузки шрифта {path}: {e}")
                continue

        # Если DejaVu не найден, попробуем другие шрифты
        if normal_font == 'Helvetica':
            try:
                arial_paths = [
                    '/usr/share/fonts/truetype/msttcorefonts/Arial_Unicode_MS.ttf',
                    '/System/Library/Fonts/Arial.ttf',
                    '/Windows/Fonts/arial.ttf'
                ]
                for path in arial_paths:
                    if os.path.exists(path):
                        pdfmetrics.registerFont(TTFont('ArialUnicode', path))
                        normal_font = 'ArialUnicode'
                        print(f"✅ Успешно загружен Arial шрифт: {path}")
                        break
            except Exception as e:
                print(f"❌ Ошибка загрузки Arial шрифта: {e}")
                pass
        
        # Если ничего не найдено, используем встроенные шрифты ReportLab
        if normal_font == 'Helvetica':
            print("⚠️ Внешние шрифты не найдены, используем встроенные")
            # Регистрируем встроенные шрифты с правильной кодировкой
            try:
                from reportlab.pdfbase.cidfonts import UnicodeCIDFont
                pdfmetrics.registerFont(UnicodeCIDFont('STSong-Light'))
                normal_font = 'STSong-Light'
                print("✅ Используем встроенный Unicode шрифт")
            except:
                # Попробуем создать простой шрифт с поддержкой кириллицы
                try:
                    # Используем Times-Roman как fallback с правильной кодировкой
                    normal_font = 'Times-Roman'
                    print("✅ Используем Times-Roman с UTF-8 кодировкой")
                except:
                    print("❌ Не удалось загрузить Unicode шрифт, используем Helvetica")
        
        print(f"📝 Используемый шрифт: {normal_font}")
    except Exception as e:
        print(f"❌ Общая ошибка настройки шрифтов: {e}")
        normal_font = 'Helvetica'
    
    return normal_font


def create_passport_styles(normal_font):
    """Создает стили для PDF паспорта"""
    styles = getSampleStyleSheet()
    
    # Стили для заголовков и текста с корректной кодировкой
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=16,
        spaceAfter=20,
        alignment=1,  # Центрирование
        fontName=normal_font,
        encoding='utf-8'
    )

    subtitle_style = ParagraphStyle(
        'CustomSubtitle',
        parent=styles['Heading2'],
        fontSize=14,
        spaceAfter=15,
        fontName=normal_font,
        encoding='utf-8'
    )

    normal_style = ParagraphStyle(
        'CustomNormal',
        parent=styles['Normal'],
        fontName=normal_font,
        fontSize=10,
        encoding='utf-8'
    )
    
    return title_style, subtitle_style, normal_style


def create_passport_pdf_content(passport, normal_font, title_style, subtitle_style, normal_style):
    """Создает содержимое PDF паспорта в новом формате согласно образцу"""
    story = []

    # Создаем контактную информацию в одну строку
    contact_info = """ООО "Алмазгеобур" 125362, г. Москва, улица Водников, дом 2, стр. 14, оф. 11, тел.:+7 495 229 82 94
LLP "Almazgeobur" 125362, Moscow, Vodnikov Street, 2, building. 14, of. 11, tel.:+7 495 229 82 94,
e-mail: contact@almazgeobur.ru"""

    # Создаем внешнюю таблицу для общей рамки
    outer_data = [[None]]  # Будет заполнено позже
    outer_table = Table(outer_data, colWidths=[190*mm])
    outer_table.setStyle(TableStyle([
        ('BOX', (0, 0), (-1, -1), 0.5, colors.black),
        ('TOPPADDING', (0, 0), (-1, -1), 2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
        ('LEFTPADDING', (0, 0), (-1, -1), 2),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2),
    ]))

    # Создаем внутреннюю таблицу с логотипом и контактными данными
    header_data = [[None, contact_info]]

    # Создаем заголовочную таблицу
    header_table = Table(header_data, colWidths=[45*mm, 143*mm])
    header_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), normal_font),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
        ('ALIGN', (0, 0), (0, 0), 'LEFT'),
        ('ALIGN', (1, 0), (1, 0), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ENCODING', (0, 0), (-1, -1), 'utf-8'),
    ]))

    # Добавляем логотип
    logo_img = create_logo_image()
    if logo_img:
        logo_cell = Image(logo_img, width=40*mm, height=12*mm)
        header_data[0][0] = logo_cell
        header_table = Table(header_data, colWidths=[45*mm, 143*mm])
        header_table.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (-1, -1), normal_font),
            ('FONTSIZE', (0, 0), (-1, -1), 7),  # Уменьшенный размер шрифта
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (0, 0), 'LEFT'),
            ('ALIGN', (1, 0), (1, 0), 'LEFT'),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('ENCODING', (0, 0), (-1, -1), 'utf-8'),
        ]))

    story.append(header_table)
    story.append(Spacer(1, 15))

    # Основная таблица с данными паспорта (как на картинке)
    # Получаем данные из БД
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
        fontSize=7,  # Уменьшенный размер шрифта
        leading=9,   # Межстрочный интервал
        spaceBefore=0,
        spaceAfter=0,
    )

    # Определяем тип продукта на основе данных из БД
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
        alignment=1,  # CENTER
    )
    
    # Создаем параграф с названием номенклатуры для автоматического переноса
    tool_type = Paragraph(f"{product_type_ru} / {product_type_en}", cell_style)

    passport_data = [
        [Paragraph("Артикул / Stock Code", cell_style), 
         Paragraph("Типоразмер / Tool size", cell_style), 
         Paragraph("Серийный номер / Serial Number", cell_style), 
         Paragraph("Буровой инструмент / Tool type", cell_style)],
        [Paragraph(nomenclature.article or "3501040", cell_style), 
         Paragraph(nomenclature.matrix or "NQ", cell_style), 
         Paragraph(passport.passport_number or "AGB 3-5 NQ 0000125", cell_style), 
         tool_type],
        [Paragraph("Матрица / Matrix", cell_style), 
         Paragraph("Высота матрицы / Imp Depth", cell_style), 
         Paragraph("Промывочные отверстия / Waterways", cell_style), 
         Paragraph("Дата производства / Production date", cell_style)],
        [Paragraph(nomenclature.matrix or "3-5", cell_style), 
         Paragraph(nomenclature.height or "12 мм", cell_style), 
         Paragraph("8 mm", cell_style), 
         "2025"],
        [Paragraph("www.almazgeobur.ru", cell_style), "", "", ""]
    ]

    # Создаем основную таблицу (без дублирующей рамки) с правильными размерами
    table = Table(passport_data, colWidths=[40*mm, 40*mm, 50*mm, 40*mm])
    table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), normal_font),
        ('FONTSIZE', (0, 0), (-1, -1), 7),  # Уменьшенный размер шрифта
        ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
        ('BOX', (0, 0), (-1, -1), 0.5, colors.black),  # Внешняя рамка
        ('BACKGROUND', (0, 0), (-1, 0), colors.lightgrey),
        ('BACKGROUND', (0, 2), (-1, 2), colors.lightgrey),
        ('SPAN', (0, 4), (3, 4)),  # Объединяем ячейку "www.almazgeobur.ru" по всей ширине
        ('ALIGN', (0, 4), (3, 4), 'CENTER'),  # Центрируем "www.almazgeobur.ru"
        ('ENCODING', (0, 0), (-1, -1), 'utf-8'),
        ('LEFTPADDING', (0, 0), (-1, -1), 2),  # Отступы для лучшего отображения
        ('RIGHTPADDING', (0, 0), (-1, -1), 2),
        ('TOPPADDING', (0, 0), (-1, -1), 2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
    ]))

    # Создаем таблицу с заголовком и основной таблицей
    inner_table = Table([[header_table], [Spacer(1, 8)], [table]], colWidths=[188*mm])
    inner_table.setStyle(TableStyle([
        ('BOX', (0, 0), (-1, -1), 1, colors.black),  # Общая рамка вокруг всего паспорта
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),  # Центрируем все содержимое
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),  # Вертикальное центрирование
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('RIGHTPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))

    story.append(inner_table)

    return story


def generate_passport_pdf(passport):
    """Генерирует PDF паспорта с правильной кодировкой и новым макетом"""
    # Используем ту же функцию, что и для массового экспорта, но с одним паспортом
    return generate_bulk_passports_pdf([passport])


def create_passport_content_without_header(passport, normal_font, normal_style):
    """Создает содержимое паспорта без заголовка для массовой выгрузки"""
    story = []
    
    # Получаем данные из БД
    nomenclature = passport.nomenclature
    if not nomenclature:
        print(f"❌ Номенклатура не найдена для паспорта {passport.passport_number}")
        return story
    
    # Создаем основную таблицу с данными паспорта
    barcode = f"AGB{nomenclature.article or '3501040'}-{passport.passport_number or '0000125'}"
    
    # Определяем тип продукта на основе данных из БД
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
        alignment=1,  # CENTER
    )
    
    # Данные паспорта с реальными данными из БД (согласно инструкциям) с переносом текста
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
         Paragraph("Высота матрицы / Imp Depth", cell_style), 
         Paragraph("Промывочные отверстия / Waterways", cell_style), 
         Paragraph("Дата производства / Production date", cell_style)],
        [Paragraph(nomenclature.matrix or "3-5", cell_style), 
         Paragraph(nomenclature.height or "12 мм", cell_style), 
         Paragraph("8 mm", cell_style),
         "2025"],
        [Paragraph("www.almazgeobur.ru", cell_style), "", "", ""]
    ]
    
    # Создаем основную таблицу (без дублирующей рамки) с правильными размерами
    table = Table(passport_data, colWidths=[40*mm, 40*mm, 50*mm, 40*mm])
    table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), normal_font),
        ('FONTSIZE', (0, 0), (-1, -1), 7),  # Уменьшенный размер шрифта
        ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
        ('BOX', (0, 0), (-1, -1), 0.5, colors.black),  # Внешняя рамка
        ('BACKGROUND', (0, 0), (-1, 0), colors.lightgrey),
        ('BACKGROUND', (0, 2), (-1, 2), colors.lightgrey),
        ('SPAN', (0, 4), (3, 4)),  # Объединяем ячейку "www.almazgeobur.ru" по всей ширине
        ('ALIGN', (0, 4), (3, 4), 'CENTER'),  # Центрируем "www.almazgeobur.ru"
        ('ENCODING', (0, 0), (-1, -1), 'utf-8'),
        ('LEFTPADDING', (0, 0), (-1, -1), 2),  # Отступы для лучшего отображения
        ('RIGHTPADDING', (0, 0), (-1, -1), 2),
        ('TOPPADDING', (0, 0), (-1, -1), 2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
    ]))
    
    story.append(table)
    return story


def generate_bulk_passports_pdf(passports):
    """Генерирует PDF с несколькими паспортами (по 3 на страницу)"""
    print(f"📄 Начинаем генерацию PDF для {len(passports)} паспортов")
    
    # Создаем PDF в памяти
    buffer = io.BytesIO()
    
    # Устанавливаем отступы страницы
    page_width, page_height = A4
    margin = 20
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=margin,
        rightMargin=margin,
        topMargin=margin,
        bottomMargin=margin
    )
    
    # Настраиваем шрифты
    normal_font = setup_cyrillic_fonts()
    
    # Создаем стили
    title_style, subtitle_style, normal_style = create_passport_styles(normal_font)
    
    story = []
    
    # Добавляем общий заголовок только один раз
    contact_info = """ООО "Алмазгеобур" 125362, г. Москва, улица Водников, дом 2, стр. 14, оф. 11, тел.:+7 495 229 82 94
LLP "Almazgeobur" 125362, Moscow, Vodnikov Street, 2, building. 14, of. 11, tel.:+7 495 229 82 94,
e-mail: contact@almazgeobur.ru"""

    # Создаем заголовочную таблицу
    header_data = [[None, contact_info]]
    logo_img = create_logo_image()
    if logo_img:
        logo_cell = Image(logo_img, width=40*mm, height=12*mm)
        header_data[0][0] = logo_cell

    header_table = Table(header_data, colWidths=[45*mm, 143*mm])
    header_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), normal_font),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
        ('ALIGN', (0, 0), (0, 0), 'LEFT'),
        ('ALIGN', (1, 0), (1, 0), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ENCODING', (0, 0), (-1, -1), 'utf-8'),
    ]))
    
    # Группируем паспорта по 3 на страницу
    for i in range(0, len(passports), 3):
        passport_group = passports[i:i+3]

        for j, passport in enumerate(passport_group):
            print(f"📄 Обрабатываем паспорт {j+1} в группе: {passport.passport_number}")
            
            # Создаем содержимое паспорта без заголовка
            passport_content = create_passport_content_without_header(passport, normal_font, normal_style)
            
            # Создаем полный паспорт с заголовком и общей рамкой
            full_passport = Table([[header_table], [Spacer(1, 8)], [passport_content]], colWidths=[188*mm])
            full_passport.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 1, colors.black),  # Общая рамка вокруг всего паспорта
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),  # Центрируем все содержимое
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),  # Вертикальное центрирование
                ('LEFTPADDING', (0, 0), (-1, -1), 5),
                ('RIGHTPADDING', (0, 0), (-1, -1), 5),
                ('TOPPADDING', (0, 0), (-1, -1), 5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
            ]))
            
            story.append(full_passport)

            # Добавляем интервал между паспортами
            if j < len(passport_group) - 1:
                story.append(Spacer(1, 8*mm))

        # Добавляем переход на новую страницу после каждой группы из 3 паспортов
        if i + 3 < len(passports):
            story.append(PageBreak())

    # Генерируем PDF
    print(f"🔨 Строим PDF документ...")
    doc.build(story)
    buffer.seek(0)
    
    pdf_content = buffer.getvalue()
    print(f"✅ PDF успешно сгенерирован, размер: {len(pdf_content)} байт")
    
    return pdf_content

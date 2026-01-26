"""
Генератор штрихкодов для наклеек
"""
import os
import tempfile
from typing import Optional


def generate_barcode_image(code: str, width_mm: float = 40, height_mm: float = 8) -> Optional[str]:
    """
    Генерирует изображение штрихкода для заданного кода
    
    Args:
        code: Текст для кодирования в штрихкод
        width_mm: Ширина штрихкода в миллиметрах (по умолчанию 40мм для узкого штрихкода)
        height_mm: Высота штрихкода в миллиметрах (по умолчанию 8мм)
    
    Returns:
        Путь к временному файлу с изображением штрихкода или None при ошибке
    """
    try:
        import barcode
        from barcode.writer import ImageWriter
        from PIL import Image
        
        # Используем Code128 для компактного штрихкода
        code128 = barcode.get_barcode_class('code128')
        barcode_instance = code128(code, writer=ImageWriter())
        
        # Создаем временный файл для изображения (без расширения, так как barcode.save добавляет его сам)
        temp_file = tempfile.NamedTemporaryFile(delete=False)
        temp_path_base = temp_file.name
        temp_file.close()
        
        # Генерируем штрихкод с настройками для высокого качества
        # Используем высокое разрешение для четкости
        dpi = 600  # Высокое разрешение для печати
        pixels_per_mm = dpi / 25.4  # Пикселей на миллиметр
        
        options = {
            'module_width': 0.3,  # Немного шире для читаемости
            'module_height': height_mm * pixels_per_mm,  # Высота в пикселях при 600dpi
            'quiet_zone': 2.0,  # Зона тишины для надежности
            'font_size': 10,  # Читаемый шрифт
            'text_distance': 2.0,  # Расстояние от текста до штрихкода
            'write_text': True,  # Показывать текст под штрихкодом
        }
        
        # Сохраняем штрихкод (библиотека добавит расширение .png)
        barcode_instance.save(temp_path_base, options=options)
        
        # Библиотека добавляет расширение .png к пути
        temp_path = temp_path_base + '.png'
        
        # Проверяем, что файл создан
        if not os.path.exists(temp_path) or os.path.getsize(temp_path) == 0:
            print(f"   ⚠️ Файл штрихкода не создан или пуст: {temp_path}")
            # Пробуем найти файл без расширения
            if os.path.exists(temp_path_base) and os.path.getsize(temp_path_base) > 0:
                temp_path = temp_path_base
            else:
                return None
        
        # Изменяем размер изображения до нужной ширины с высоким качеством
        img = Image.open(temp_path)
        # Вычисляем новую ширину в пикселях при 600dpi
        target_width_px = int(width_mm * pixels_per_mm)
        target_height_px = int(height_mm * pixels_per_mm)
        
        # Используем resize вместо thumbnail для точного размера и лучшего качества
        img_resized = img.resize((target_width_px, target_height_px), Image.Resampling.LANCZOS)
        
        # Сохраняем измененное изображение с высоким DPI
        img_resized.save(temp_path, 'PNG', dpi=(dpi, dpi))
        
        print(f"   ✅ Штрихкод создан: {code} (размер: {width_mm}x{height_mm}мм)")
        return temp_path
        
    except ImportError:
        print(f"   ⚠️ Библиотека python-barcode не установлена, штрихкод не будет создан")
        return None
    except Exception as e:
        print(f"   ⚠️ Ошибка при создании штрихкода для '{code}': {e}")
        import traceback
        traceback.print_exc()
        return None

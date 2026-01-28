"""
Единый менеджер для работы с шаблонами
Обеспечивает стабильную работу с шаблонами и их редактирование пользователями
"""
import os
import shutil
from pathlib import Path
from typing import Optional, Tuple
from datetime import datetime


class TemplateManager:
    """Менеджер для работы с шаблонами"""
    
    # Единая директория для шаблонов (редактируемая пользователями)
    TEMPLATES_DIR = Path("/app/templates")
    BACKUPS_DIR = Path("/app/templates/backups")
    
    # Типы шаблонов
    TEMPLATE_TYPES = {
        "sticker": "sticker_template.xlsx",  # Excel шаблон наклеек
        "passport": "passport_template.docx"
    }
    
    # Логотип
    LOGO_FILENAME = "logo.png"
    
    def __init__(self):
        """Инициализация менеджера шаблонов"""
        self._ensure_directories()
    
    def _ensure_directories(self):
        """Создает необходимые директории"""
        try:
            self.TEMPLATES_DIR.mkdir(parents=True, exist_ok=True)
            self.BACKUPS_DIR.mkdir(parents=True, exist_ok=True)
        except (OSError, PermissionError) as e:
            print(f"⚠️ Не удалось создать директории шаблонов: {e}")
            # Fallback на /tmp
            self.TEMPLATES_DIR = Path("/tmp/templates")
            self.BACKUPS_DIR = Path("/tmp/templates/backups")
            self.TEMPLATES_DIR.mkdir(parents=True, exist_ok=True)
            self.BACKUPS_DIR.mkdir(parents=True, exist_ok=True)
    
    def get_template_path(self, template_type: str) -> Optional[Path]:
        """
        Получает путь к шаблону из /app/templates
        
        Args:
            template_type: Тип шаблона ('sticker' или 'passport')
            
        Returns:
            Path к шаблону или None если не найден
        """
        if template_type not in self.TEMPLATE_TYPES:
            return None
        
        filename = self.TEMPLATE_TYPES[template_type]
        
        # Единственная директория для шаблонов
        template_path = self.TEMPLATES_DIR / filename
        if template_path.exists() and template_path.is_file():
            return template_path
        
        return None
    
    def get_logo_path(self) -> Optional[Path]:
        """
        Получает путь к логотипу из /app/templates/logo.png
        
        Returns:
            Path к логотипу или None если не найден
        """
        logo_path = self.TEMPLATES_DIR / self.LOGO_FILENAME
        if logo_path.exists() and logo_path.is_file():
            return logo_path
        
        return None
    
    def create_logo_if_missing(self) -> Optional[Path]:
        """
        Создает логотип если его нет (используя функцию из pdf_generator)
        
        Returns:
            Path к логотипу или None
        """
        logo_path = self.get_logo_path()
        if logo_path:
            return logo_path
        
        # Пытаемся создать через функцию
        try:
            from backend.utils.pdf_generator import create_logo_image
            created_path = create_logo_image()
            if created_path and os.path.exists(created_path):
                # Копируем в редактируемую директорию
                target_path = self.TEMPLATES_DIR / self.LOGO_FILENAME
                shutil.copy2(created_path, target_path)
                return target_path
        except Exception as e:
            print(f"⚠️ Не удалось создать логотип: {e}")
        
        return None
    
    def save_template(self, template_type: str, content: bytes, create_backup: bool = True) -> Tuple[bool, str]:
        """
        Сохраняет шаблон в редактируемую директорию
        
        Args:
            template_type: Тип шаблона
            content: Содержимое файла
            create_backup: Создавать ли резервную копию
            
        Returns:
            Tuple (успех, сообщение)
        """
        if template_type not in self.TEMPLATE_TYPES:
            return False, "Неверный тип шаблона"
        
        filename = self.TEMPLATE_TYPES[template_type]
        template_path = self.TEMPLATES_DIR / filename
        
        # Создаем бэкап
        if create_backup and template_path.exists():
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_filename = f"{template_type}_{timestamp}.docx"
            backup_path = self.BACKUPS_DIR / backup_filename
            try:
                shutil.copy2(template_path, backup_path)
            except Exception as e:
                print(f"⚠️ Не удалось создать бэкап: {e}")
        
        # Сохраняем шаблон
        try:
            template_path.write_bytes(content)
            return True, f"Шаблон сохранен: {template_path}"
        except Exception as e:
            return False, f"Ошибка сохранения: {str(e)}"
    
    def template_exists(self, template_type: str) -> bool:
        """Проверяет существование шаблона"""
        return self.get_template_path(template_type) is not None
    
    def get_template_info(self, template_type: str) -> Optional[dict]:
        """
        Получает информацию о шаблоне
        
        Returns:
            Dict с информацией или None
        """
        template_path = self.get_template_path(template_type)
        if not template_path:
            return None
        
        try:
            stat = template_path.stat()
            return {
                "type": template_type,
                "filename": template_path.name,
                "path": str(template_path),
                "size": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "exists": True
            }
        except Exception as e:
            print(f"⚠️ Ошибка получения информации о шаблоне: {e}")
            return None


# Глобальный экземпляр менеджера
_template_manager = None


def get_template_manager() -> TemplateManager:
    """Получает глобальный экземпляр менеджера шаблонов"""
    global _template_manager
    if _template_manager is None:
        _template_manager = TemplateManager()
    return _template_manager

# Локальная разработка и тестирование

## Быстрый старт

### 1. Подготовка окружения

```bash
# Убедитесь, что Docker запущен
docker --version
docker compose version

# Создайте папку для редактируемых шаблонов (если еще не создана)
mkdir -p templates

# Скопируйте шаблоны из legacy папки в новую (если нужно)
cp -r backend/utils/templates/* templates/ 2>/dev/null || true
```

### 2. Запуск проекта

```bash
# Остановите все контейнеры (если запущены)
docker compose down

# Запустите все сервисы
docker compose up -d

# Проверьте статус
docker compose ps

# Посмотрите логи
docker compose logs -f backend
```

### 3. Инициализация базы данных

```bash
# Создайте администратора
docker compose exec backend python create_admin.py

# Или используйте скрипт
python setup_and_run.py
```

### 4. Доступ к приложению

- **Frontend:** http://localhost:80 (через nginx)
- **Backend API:** http://localhost:8000
- **API Docs:** http://localhost:8000/docs
- **PostgreSQL:** localhost:5435

### 5. Тестирование экспорта наклеек

1. Войдите в систему (admin/admin)
2. Создайте несколько паспортов
3. Выберите паспорта и экспортируйте наклейки (DOCX)
4. Проверьте, что:
   - Наклейки выглядят как в шаблоне
   - Штрихкоды присутствуют
   - Логотип отображается

### 6. Проверка логов

```bash
# Логи бэкенда
docker compose logs -f backend | grep -i "штрихкод\|barcode\|изображение\|рендер"

# Все логи
docker compose logs -f
```

### 7. Остановка

```bash
docker compose down
```

## Структура шаблонов

- `backend/utils/templates/` - Legacy шаблоны (read-only, fallback)
- `templates/` - Редактируемые шаблоны пользователями
  - `sticker_template.docx` - Шаблон наклеек
  - `logo.png` - Логотип компании
  - `backups/` - Автоматические бэкапы шаблонов

## Отладка

### Проверка генерации штрихкодов

```bash
docker compose exec backend python3 -c "
from backend.utils.barcode_generator import generate_barcode_image
import os
path = generate_barcode_image('TEST123', width_mm=35, height_mm=6)
if path and os.path.exists(path):
    print(f'✅ Штрихкод создан: {path}')
    os.unlink(path)
else:
    print('❌ Ошибка создания штрихкода')
"
```

### Проверка шаблонов

```bash
docker compose exec backend python3 -c "
from backend.utils.template_manager import get_template_manager
manager = get_template_manager()
sticker_path = manager.get_template_path('sticker')
logo_path = manager.get_logo_path()
print(f'Шаблон наклеек: {sticker_path}')
print(f'Логотип: {logo_path}')
"
```

## Проблемы и решения

### Проблема: Штрихкоды не генерируются
**Решение:** Убедитесь, что `python-barcode[images]` установлен:
```bash
docker compose exec backend pip install python-barcode[images]
```

### Проблема: Шаблон не найден
**Решение:** Проверьте, что шаблоны скопированы:
```bash
ls -la templates/
ls -la backend/utils/templates/
```

### Проблема: Изображения не копируются
**Решение:** Проверьте логи при экспорте - там будет видно, сколько изображений найдено и скопировано.

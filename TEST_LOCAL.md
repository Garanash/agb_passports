# Тестирование локально

## Чеклист тестирования

### 1. Запуск проекта
```bash
./start_local.sh
```

### 2. Проверка сервисов
```bash
# Проверка статуса
docker compose ps

# Проверка логов
docker compose logs backend | tail -20
```

### 3. Тестирование экспорта наклеек

1. **Вход в систему**
   - Откройте http://localhost:80
   - Войдите как admin/admin

2. **Создание паспортов**
   - Создайте несколько паспортов
   - Убедитесь, что они отображаются в списке

3. **Экспорт наклеек**
   - Выберите несколько паспортов
   - Нажмите "Экспорт наклеек" (DOCX)
   - Скачайте файл

4. **Проверка результата**
   - Откройте скачанный DOCX файл в Word
   - Проверьте:
     - ✅ Наклейки выглядят как в шаблоне
     - ✅ Логотип присутствует
     - ✅ Штрихкоды для stock_code присутствуют
     - ✅ Штрихкоды для serial_number_code присутствуют
     - ✅ Все данные подставлены правильно

### 4. Проверка логов

```bash
# Логи генерации наклеек
docker compose logs backend | grep -i "штрихкод\|barcode\|изображение\|рендер\|наклейк"

# Логи ошибок
docker compose logs backend | grep -i "error\|ошибка\|exception"
```

### 5. Отладка проблем

#### Штрихкоды не генерируются
```bash
docker compose exec backend python3 -c "
from backend.utils.barcode_generator import generate_barcode_image
import os
path = generate_barcode_image('TEST123', width_mm=35, height_mm=6)
print(f'Результат: {path}')
if path and os.path.exists(path):
    print(f'✅ Файл создан, размер: {os.path.getsize(path)} байт')
    os.unlink(path)
"
```

#### Шаблоны не найдены
```bash
docker compose exec backend python3 -c "
from backend.utils.template_manager import get_template_manager
manager = get_template_manager()
print(f'Шаблон: {manager.get_template_path(\"sticker\")}')
print(f'Логотип: {manager.get_logo_path()}')
"
```

#### Изображения не копируются
Проверьте логи при экспорте - должно быть видно:
- "Изображений в рендеренном документе: X"
- "Изображение скопировано: ..."
- "X изображений" после копирования

### 6. После успешного тестирования

1. **Коммит в git**
```bash
git add .
git commit -m "Исправлена генерация наклеек: добавлены штрихкоды, улучшено копирование содержимого"
git push
```

2. **Деплой на сервер**
```bash
# Используйте ваш скрипт деплоя
./deploy.sh
```

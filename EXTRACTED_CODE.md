# Извлеченный код для приложения паспортов коронок

## Обзор

Из основного проекта AGB был выделен весь код, связанный с созданием паспортов на коронки, и сформировано отдельное автономное приложение `agb_pasports`.

## Извлеченные компоненты

### Backend (Python/FastAPI)

#### Модели данных
- **VedPassport** - основная модель паспортов коронок
- **VEDNomenclature** - номенклатура коронок
- **PassportCounter** - счетчики для генерации номеров
- **User** - пользователи системы

#### API эндпоинты
- **passports.py** - основные операции с паспортами
- **auth.py** - аутентификация
- **schemas.py** - схемы данных Pydantic

#### Утилиты
- **pdf_generator.py** - генерация PDF паспортов
- **database.py** - настройка базы данных

### Frontend (React/TypeScript)

#### Компоненты
- **CreatePassportPage.tsx** - главная страница создания паспортов
- **NomenclatureSelector.tsx** - выбор номенклатуры
- **BulkInputArea.tsx** - массовый ввод данных
- **PassportPreview.tsx** - предварительный просмотр паспорта

## Ключевые функции

### 1. Автоматическая генерация номеров паспортов
```python
@staticmethod
async def generate_passport_number(db: AsyncSession, matrix: str, drilling_depth: str = None, article: str = None, product_type: str = None) -> str:
    """Генерация номера паспорта используя счетчик из БД
    
    Правила генерации номеров паспортов:
    Коронки: AGB [Глубина бурения] [Матрица] [Серийный номер] [Год]
    Пример: AGB 05-07 NQ 000001 25
    
    Расширители и башмаки: AGB [Матрица] [Серийный номер] [Год]
    Пример: AGB NQ 000001 25
    """
```

### 2. Массовое создание паспортов
```python
@router.post("/bulk/", response_model=APIResponse)
async def create_bulk_passports(
    bulk_data: BulkPassportCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Массовое создание паспортов ВЭД"""
```

### 3. PDF генерация
```python
def generate_bulk_passports_pdf(passports):
    """Генерация PDF для нескольких паспортов"""
```

### 4. Валидация данных
```typescript
const validateItem = (item: BulkInputItem) => {
    if (!item.code_1c.trim()) {
        item.isValid = false
        item.error = 'Введите код 1С'
        return
    }
    // ... дополнительная валидация
}
```

## Извлеченные файлы из основного проекта

### Backend
- `backend/models.py` → `agb_pasports/backend/models.py`
- `backend/api/v1/endpoints/ved_passports_simple.py` → `agb_pasports/backend/api/v1/endpoints/passports.py`
- `backend/api/v1/endpoints/ved_passports_upload.py` → частично интегрирован
- `backend/utils/pdf_generator.py` → `agb_pasports/backend/utils/pdf_generator.py`
- `backend/api/v1/schemas.py` → `agb_pasports/backend/api/schemas.py`

### Frontend
- `frontend/app/ved-passports/create/page.tsx` → `agb_pasports/frontend/components/CreatePassportPage.tsx`
- `frontend/components/NomenclatureSelector.tsx` → `agb_pasports/frontend/components/NomenclatureSelector.tsx`
- `frontend/components/PassportPreview.tsx` → `agb_pasports/frontend/components/PassportPreview.tsx`
- `frontend/components/ui/BulkInputArea.tsx` → `agb_pasports/frontend/components/BulkInputArea.tsx`

## Адаптации и улучшения

### 1. Упрощение архитектуры
- Убраны зависимости от основного проекта
- Создана автономная система аутентификации
- Упрощена структура базы данных

### 2. Улучшение UX
- Добавлена валидация в реальном времени
- Улучшена обработка ошибок
- Добавлены индикаторы загрузки

### 3. Оптимизация производительности
- Асинхронные операции с базой данных
- Оптимизированные запросы
- Кэширование номенклатуры

## Технические особенности

### База данных
- SQLite для простоты развертывания
- Автоматическое создание таблиц
- Миграции через Alembic

### API
- RESTful архитектура
- Автоматическая документация (Swagger)
- Валидация через Pydantic

### Frontend
- React с TypeScript
- Tailwind CSS для стилизации
- Компонентная архитектура

## Зависимости

### Python
- FastAPI - веб-фреймворк
- SQLAlchemy - ORM
- ReportLab - генерация PDF
- Pydantic - валидация данных

### JavaScript/TypeScript
- React - UI библиотека
- Next.js - фреймворк
- Tailwind CSS - стилизация
- Heroicons - иконки

## Запуск

Приложение полностью автономно и запускается одной командой:
```bash
./start.sh
```

## Заключение

Извлеченное приложение содержит весь необходимый функционал для создания паспортов коронок и может работать независимо от основного проекта AGB. Код адаптирован для автономной работы с улучшенной архитектурой и пользовательским интерфейсом.

# AGB Passports - Docker Deployment

## Быстрый запуск

```bash
# Запуск всего проекта в Docker
./run_docker.sh
```

## Ручной запуск

### 1. Запуск всех сервисов
```bash
docker-compose up -d
```

### 2. Загрузка номенклатур из Excel
```bash
docker-compose run --rm nomenclature_loader
```

### 3. Просмотр логов
```bash
docker-compose logs -f
```

## Структура сервисов

- **postgres** - PostgreSQL база данных (порт 5432)
- **backend** - FastAPI приложение (порт 8000)
- **frontend** - Next.js приложение (порт 3000)
- **nomenclature_loader** - Загрузка номенклатур из Excel

## Доступные адреса

- Frontend: http://localhost:3001
- Backend API: http://localhost:8000
- API документация: http://localhost:8000/docs
- PostgreSQL: localhost:5435

## Полезные команды

```bash
# Остановка всех сервисов
docker-compose down

# Перезапуск конкретного сервиса
docker-compose restart backend
docker-compose restart frontend

# Просмотр статуса сервисов
docker-compose ps

# Просмотр логов конкретного сервиса
docker-compose logs backend
docker-compose logs frontend
docker-compose logs postgres

# Вход в контейнер
docker-compose exec backend bash
docker-compose exec postgres psql -U postgres -d agb_passports
```

## Переменные окружения

Основные переменные окружения в `docker-compose.yml`:

- `POSTGRES_DB=agb_passports`
- `POSTGRES_USER=postgres`
- `POSTGRES_PASSWORD=password`
- `DATABASE_URL=postgresql://postgres:password@postgres:5432/agb_passports`

## Файлы конфигурации

- `docker-compose.yml` - Основная конфигурация Docker Compose
- `Dockerfile.backend` - Dockerfile для backend
- `Dockerfile.frontend` - Dockerfile для frontend
- `init.sql` - SQL скрипт инициализации базы данных
- `load_nomenclature.py` - Скрипт загрузки номенклатур

## Требования

- Docker
- Docker Compose
- Excel файл с номенклатурами: `Номенклатура алмазный инстурмент ALFA.xlsx`

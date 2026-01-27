# Отчет о статусе сервера

**Дата проверки:** 27 января 2026  
**URL:** http://185.247.17.188/  
**Статус:** ❌ **502 Bad Gateway**

## Результаты проверки

### ✅ Работающие компоненты

1. **Nginx** - работает
   - Порт 80 доступен
   - Health check endpoint работает: `http://185.247.17.188/health` → возвращает "healthy"
   - Версия: nginx/1.29.3

### ❌ Проблемы

1. **Главная страница** - 502 Bad Gateway
   - `http://185.247.17.188/` → 502 Bad Gateway
   - Nginx не может подключиться к frontend контейнеру

2. **API endpoints** - 502 Bad Gateway
   - `http://185.247.17.188/api/v1/` → 502 Bad Gateway (таймаут 7 секунд)
   - Nginx не может подключиться к backend контейнеру

3. **Прямой доступ к контейнерам** - недоступен
   - Порт 8000 (backend) - Connection refused
   - Порт 3000 (frontend) - Connection refused
   - Это нормально, если порты не проброшены наружу, но контейнеры должны быть доступны внутри Docker сети

## Диагностика проблемы

### Возможные причины:

1. **Контейнеры не запущены**
   - Backend контейнер (`agb_backend_prod`) не запущен
   - Frontend контейнер (`agb_frontend_prod`) не запущен

2. **Контейнеры не в сети Docker**
   - Контейнеры не подключены к сети `agb_network`
   - Nginx не может найти контейнеры по именам `backend` и `frontend`

3. **Контейнеры упали/перезапускаются**
   - Ошибки при запуске backend/frontend
   - Проблемы с подключением к базе данных

4. **Проблемы с конфигурацией nginx**
   - Неправильные upstream имена в nginx.production.conf
   - Неправильные пути проксирования

## Команды для диагностики на сервере

```bash
# Проверка статуса контейнеров
docker ps -a | grep agb

# Проверка логов backend
docker logs agb_backend_prod --tail 50

# Проверка логов frontend
docker logs agb_frontend_prod --tail 50

# Проверка логов nginx
docker logs agb_nginx_prod --tail 50

# Проверка сети Docker
docker network inspect agb_network

# Проверка подключения backend к БД
docker exec agb_backend_prod python -c "from backend.database import engine; print('DB OK')"

# Проверка доступности backend из nginx
docker exec agb_nginx_prod wget -O- http://backend:8000/health

# Проверка доступности frontend из nginx
docker exec agb_nginx_prod wget -O- http://frontend:3000/
```

## Рекомендации по исправлению

### 1. Проверить статус контейнеров

```bash
cd /root/agb_passports
docker-compose -f docker-compose.production.yml ps
```

### 2. Перезапустить контейнеры

```bash
cd /root/agb_passports
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d
```

### 3. Проверить логи

```bash
# Логи всех сервисов
docker-compose -f docker-compose.production.yml logs --tail 100

# Логи конкретного сервиса
docker-compose -f docker-compose.production.yml logs backend --tail 50
docker-compose -f docker-compose.production.yml logs frontend --tail 50
```

### 4. Проверить переменные окружения

```bash
# Убедиться, что файл .env.prod существует и содержит все необходимые переменные
cat .env.prod

# Проверить переменные в контейнере
docker exec agb_backend_prod env | grep -E "DATABASE_URL|SECRET_KEY"
```

### 5. Проверить подключение к базе данных

```bash
# Проверить, что postgres контейнер работает
docker ps | grep postgres

# Проверить подключение из backend
docker exec agb_backend_prod python -c "
from backend.database import engine
try:
    with engine.connect() as conn:
        print('✅ Подключение к БД успешно')
except Exception as e:
    print(f'❌ Ошибка подключения: {e}')
"
```

### 6. Проверить файлы шаблонов

```bash
# Проверить наличие шаблонов в контейнере
docker exec agb_backend_prod ls -la /app/templates
docker exec agb_backend_prod ls -la /app/backend/utils/templates
```

## Быстрое исправление

Если контейнеры не запущены, выполните:

```bash
cd /root/agb_passports

# Остановить все контейнеры
docker-compose -f docker-compose.production.yml down

# Запустить все контейнеры заново
docker-compose -f docker-compose.production.yml up -d

# Подождать 10 секунд для запуска
sleep 10

# Проверить статус
docker-compose -f docker-compose.production.yml ps

# Проверить логи
docker-compose -f docker-compose.production.yml logs --tail 50
```

## Ожидаемый результат после исправления

- ✅ `http://185.247.17.188/` → главная страница фронтенда
- ✅ `http://185.247.17.188/api/v1/` → API документация или JSON ответ
- ✅ `http://185.247.17.188/health` → "healthy" (уже работает)

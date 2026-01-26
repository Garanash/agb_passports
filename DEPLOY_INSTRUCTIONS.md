# Инструкция по запуску приложения на сервере

## Быстрый запуск

### 1. Подключитесь к серверу по SSH:
```bash
ssh root@185.247.17.188
# или
ssh user@185.247.17.188
```

### 2. Перейдите в директорию проекта:
```bash
cd /root/agb_passports
# или
cd ~/agb_passports
```

### 3. Запустите скрипт автоматического запуска:
```bash
./start_server.sh
```

Скрипт автоматически:
- Остановит старые контейнеры
- Соберет новые образы
- Запустит все сервисы в правильном порядке
- Проверит здоровье всех контейнеров
- Проверит доступность API и frontend

## Ручной запуск

Если автоматический скрипт не работает, выполните команды вручную:

### 1. Остановите старые контейнеры:
```bash
docker-compose down
# или
docker compose down
```

### 2. Удалите старые контейнеры (если нужно):
```bash
docker rm -f agb_postgres agb_backend agb_frontend agb_nginx
```

### 3. Создайте сеть (если не существует):
```bash
docker network create agb_network 2>/dev/null || true
```

### 4. Запустите PostgreSQL:
```bash
docker-compose up -d postgres
```

### 5. Дождитесь готовности PostgreSQL:
```bash
# Проверка готовности
docker exec agb_postgres pg_isready -U postgres

# Установка пароля (если нужно)
docker exec agb_postgres psql -U postgres -c "ALTER ROLE postgres WITH PASSWORD 'password';"
```

### 6. Запустите backend:
```bash
docker-compose up -d --build backend
```

### 7. Проверьте логи backend:
```bash
docker logs agb_backend --tail 50
```

### 8. Запустите frontend:
```bash
docker-compose up -d --build frontend
```

### 9. Запустите nginx:
```bash
docker-compose up -d nginx
```

### 10. Проверьте статус всех контейнеров:
```bash
docker-compose ps
```

## Проверка работоспособности

### Проверка API:
```bash
curl http://localhost:8000/docs
# или
curl http://185.247.17.188:8000/docs
```

### Проверка frontend:
```bash
curl http://localhost:3000
# или
curl http://185.247.17.188:3000
```

### Проверка через nginx:
```bash
curl http://localhost
# или
curl http://185.247.17.188
```

## Просмотр логов

### Все сервисы:
```bash
docker-compose logs -f
```

### Отдельные сервисы:
```bash
# Backend
docker logs agb_backend --tail 100 -f

# Frontend
docker logs agb_frontend --tail 100 -f

# PostgreSQL
docker logs agb_postgres --tail 100 -f

# Nginx
docker logs agb_nginx --tail 100 -f
```

## Решение проблем

### Проблема: Контейнеры не запускаются

1. Проверьте логи:
```bash
docker-compose logs
```

2. Проверьте статус:
```bash
docker-compose ps -a
```

3. Пересоберите образы:
```bash
docker-compose build --no-cache
docker-compose up -d
```

### Проблема: Ошибка подключения к базе данных

1. Проверьте пароль PostgreSQL:
```bash
docker exec agb_postgres psql -U postgres -c "ALTER ROLE postgres WITH PASSWORD 'password';"
```

2. Перезапустите backend:
```bash
docker-compose restart backend
```

3. Используйте скрипт проверки:
```bash
./check_and_fix_db.sh
```

### Проблема: Frontend не собирается

1. Проверьте логи сборки:
```bash
docker logs agb_frontend
```

2. Пересоберите frontend:
```bash
docker-compose build --no-cache frontend
docker-compose up -d frontend
```

### Проблема: Nginx не проксирует запросы

1. Проверьте конфигурацию nginx:
```bash
docker exec agb_nginx nginx -t
```

2. Перезапустите nginx:
```bash
docker-compose restart nginx
```

3. Проверьте логи:
```bash
docker logs agb_nginx
```

## Остановка приложения

```bash
docker-compose down
```

## Полная переустановка

```bash
# Остановка и удаление контейнеров
docker-compose down -v

# Удаление образов
docker rmi $(docker images | grep agb | awk '{print $3}') 2>/dev/null || true

# Запуск заново
./start_server.sh
```

## Мониторинг

### Проверка использования ресурсов:
```bash
docker stats
```

### Проверка дискового пространства:
```bash
docker system df
```

### Очистка неиспользуемых ресурсов:
```bash
docker system prune -a
```

## Важные файлы

- `docker-compose.yml` - основная конфигурация Docker Compose
- `start_server.sh` - скрипт автоматического запуска
- `check_and_fix_db.sh` - скрипт проверки и исправления БД
- `nginx.production.conf` - конфигурация Nginx

## Контакты и поддержка

При возникновении проблем проверьте:
1. Логи всех контейнеров
2. Статус контейнеров (`docker-compose ps`)
3. Доступность портов (8000, 3000, 80)
4. Подключение к базе данных

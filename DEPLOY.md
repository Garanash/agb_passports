# AGB Passports - Руководство по деплою

## 🚀 Быстрый старт

### Локальный запуск (разработка)
```bash
# Запуск всех сервисов
docker-compose up -d

# Просмотр логов
docker-compose logs -f

# Остановка
docker-compose down
```

### Продакшн деплой

1. **Подготовка сервера**
   ```bash
   # Установка Docker и Docker Compose
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   
   # Установка Docker Compose
   sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

2. **Настройка переменных окружения**
   ```bash
   # Копируем пример конфигурации
   cp env.prod.example .env.prod
   
   # Редактируем настройки
   nano .env.prod
   ```

3. **Запуск деплоя**
   ```bash
   # Автоматический деплой
   ./deploy.sh
   ```

## 📋 Конфигурация

### Переменные окружения (.env.prod)

| Переменная | Описание | Пример |
|------------|----------|---------|
| `POSTGRES_PASSWORD` | Пароль для PostgreSQL | `secure_password_123` |
| `SECRET_KEY` | Секретный ключ для JWT | `your-secret-key-here` |
| `ALLOWED_HOSTS` | Разрешенные хосты | `your-domain.com,www.your-domain.com` |
| `NEXT_PUBLIC_API_URL` | URL API для фронтенда | `https://your-domain.com` |

### Порты

- **80** - HTTP (Nginx)
- **443** - HTTPS (Nginx, если настроен SSL)
- **8000** - Backend API (внутренний)
- **3000** - Frontend (внутренний)
- **5432** - PostgreSQL (внутренний)

## 🔧 Управление

### Основные команды

```bash
# Просмотр статуса сервисов
docker-compose -f docker-compose.prod.yml ps

# Просмотр логов
docker-compose -f docker-compose.prod.yml logs -f [service_name]

# Перезапуск сервиса
docker-compose -f docker-compose.prod.yml restart [service_name]

# Остановка всех сервисов
docker-compose -f docker-compose.prod.yml down

# Обновление и перезапуск
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
```

### Резервное копирование

```bash
# Создание бэкапа базы данных
./backup.sh

# Автоматическое резервное копирование (crontab)
0 2 * * * /path/to/agb_passports/backup.sh
```

## 🔒 Безопасность

### SSL/HTTPS настройка

1. **Получение SSL сертификата**
   ```bash
   # Используя Let's Encrypt
   sudo apt install certbot
   sudo certbot certonly --standalone -d your-domain.com
   ```

2. **Настройка Nginx для HTTPS**
   - Раскомментируйте HTTPS секцию в `nginx.conf`
   - Укажите пути к сертификатам
   - Перезапустите Nginx

### Firewall настройка

```bash
# UFW (Ubuntu)
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

## 📊 Мониторинг

### Проверка здоровья системы

```bash
# Проверка API
curl http://localhost/api/v1/passports/health

# Проверка фронтенда
curl http://localhost

# Проверка базы данных
docker-compose -f docker-compose.prod.yml exec postgres pg_isready
```

### Логи и отладка

```bash
# Все логи
docker-compose -f docker-compose.prod.yml logs

# Логи конкретного сервиса
docker-compose -f docker-compose.prod.yml logs backend
docker-compose -f docker-compose.prod.yml logs frontend
docker-compose -f docker-compose.prod.yml logs postgres
docker-compose -f docker-compose.prod.yml logs nginx
```

## 🚨 Устранение неполадок

### Частые проблемы

1. **API недоступен**
   ```bash
   # Проверяем логи backend
   docker-compose -f docker-compose.prod.yml logs backend
   
   # Проверяем подключение к БД
   docker-compose -f docker-compose.prod.yml exec backend python -c "from backend.database import get_db; print('DB OK')"
   ```

2. **Фронтенд не загружается**
   ```bash
   # Проверяем логи frontend
   docker-compose -f docker-compose.prod.yml logs frontend
   
   # Проверяем сборку
   docker-compose -f docker-compose.prod.yml exec frontend npm run build
   ```

3. **База данных недоступна**
   ```bash
   # Проверяем статус PostgreSQL
   docker-compose -f docker-compose.prod.yml exec postgres pg_isready
   
   # Проверяем логи
   docker-compose -f docker-compose.prod.yml logs postgres
   ```

### Восстановление из бэкапа

```bash
# Остановка сервисов
docker-compose -f docker-compose.prod.yml down

# Восстановление базы данных
gunzip -c /backups/agb_passports_YYYYMMDD_HHMMSS.sql.gz | docker-compose -f docker-compose.prod.yml exec -T postgres psql -U postgres -d agb_passports

# Запуск сервисов
docker-compose -f docker-compose.prod.yml up -d
```

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи сервисов
2. Убедитесь в правильности конфигурации
3. Проверьте доступность портов
4. Убедитесь в наличии свободного места на диске

## 🔄 Обновление

```bash
# Получение обновлений
git pull origin main

# Пересборка и перезапуск
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d
```

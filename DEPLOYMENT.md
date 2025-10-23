# 🚀 Развертывание AGB Passports на сервере

Это руководство поможет вам развернуть систему AGB Passports на production сервере.

## 📋 Требования

### Системные требования
- **OS**: Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- **RAM**: Минимум 2GB, рекомендуется 4GB+
- **CPU**: 2 ядра, рекомендуется 4+
- **Диск**: Минимум 10GB свободного места
- **Сеть**: Доступ к интернету для загрузки образов

### Программное обеспечение
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **Git**: Для клонирования репозитория

## 🛠 Установка зависимостей

### Ubuntu/Debian
```bash
# Обновляем систему
sudo apt update && sudo apt upgrade -y

# Устанавливаем Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Устанавливаем Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Устанавливаем Git
sudo apt install git -y
```

### CentOS/RHEL
```bash
# Устанавливаем Docker
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Устанавливаем Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Устанавливаем Git
sudo yum install git -y
```

## 📥 Получение кода

```bash
# Клонируем репозиторий
git clone https://github.com/Garanash/agb_passports.git
cd agb_passports

# Переходим на нужную ветку (если необходимо)
git checkout main
```

## ⚙️ Настройка окружения

### 1. Создание файла окружения
```bash
# Создаем файл .env.production
cat > .env.production << EOF
# Production Environment Variables
POSTGRES_PASSWORD=your_secure_password_here
SECRET_KEY=your_super_secret_key_here
API_URL=http://your-domain.com:8000

# SSL Configuration (для HTTPS)
# SSL_CERT_PATH=/etc/nginx/ssl/cert.pem
# SSL_KEY_PATH=/etc/nginx/ssl/key.pem
EOF
```

### 2. Настройка SSL (опционально)
```bash
# Создаем директорию для SSL сертификатов
mkdir -p ssl

# Помещаем ваши SSL сертификаты
# cp your-cert.pem ssl/cert.pem
# cp your-key.pem ssl/key.pem
```

## 🚀 Развертывание

### Автоматическое развертывание
```bash
# Запускаем автоматический скрипт развертывания
./deploy.sh

# Для полной пересборки (если нужно)
./deploy.sh --clean
```

### Ручное развертывание
```bash
# 1. Собираем образы
docker-compose -f docker-compose.production.yml build

# 2. Запускаем сервисы
docker-compose -f docker-compose.production.yml up -d

# 3. Инициализируем базу данных
./init_database.sh
```

## 🔍 Проверка развертывания

### Проверка статуса сервисов
```bash
docker-compose -f docker-compose.production.yml ps
```

### Проверка логов
```bash
# Все сервисы
docker-compose -f docker-compose.production.yml logs -f

# Конкретный сервис
docker-compose -f docker-compose.production.yml logs -f backend
docker-compose -f docker-compose.production.yml logs -f frontend
docker-compose -f docker-compose.production.yml logs -f postgres
docker-compose -f docker-compose.production.yml logs -f nginx
```

### Проверка доступности
```bash
# API
curl http://localhost:8000/docs

# Фронтенд
curl http://localhost:3000

# Через nginx
curl http://localhost
```

## 🌐 Доступ к приложению

После успешного развертывания приложение будет доступно по адресам:

- **Основное приложение**: http://your-domain.com
- **API**: http://your-domain.com:8000
- **API документация**: http://your-domain.com:8000/docs
- **База данных**: your-domain.com:5432

### Данные для входа
- **Логин**: admin
- **Пароль**: admin123

⚠️ **Важно**: Смените пароль администратора после первого входа!

## 🔧 Управление сервисами

### Основные команды
```bash
# Остановка всех сервисов
docker-compose -f docker-compose.production.yml down

# Перезапуск сервисов
docker-compose -f docker-compose.production.yml restart

# Перезапуск конкретного сервиса
docker-compose -f docker-compose.production.yml restart backend

# Обновление и перезапуск
docker-compose -f docker-compose.production.yml up -d --build
```

### Резервное копирование
```bash
# Создание бекапа базы данных
docker-compose -f docker-compose.production.yml exec postgres pg_dump -U postgres agb_passports > backup_$(date +%Y%m%d_%H%M%S).sql

# Восстановление из бекапа
docker-compose -f docker-compose.production.yml exec -T postgres psql -U postgres agb_passports < backup_file.sql
```

## 🔒 Безопасность

### Рекомендации по безопасности
1. **Смените пароли по умолчанию** в файле `.env.production`
2. **Настройте SSL** для HTTPS соединений
3. **Ограничьте доступ** к портам базы данных (5432)
4. **Настройте файрвол** для ограничения доступа
5. **Регулярно обновляйте** Docker образы

### Настройка файрвола (UFW)
```bash
# Устанавливаем UFW
sudo apt install ufw -y

# Разрешаем SSH
sudo ufw allow ssh

# Разрешаем HTTP и HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Запускаем файрвол
sudo ufw enable
```

## 📊 Мониторинг

### Проверка ресурсов
```bash
# Использование ресурсов контейнерами
docker stats

# Использование диска
df -h

# Использование памяти
free -h
```

### Логи системы
```bash
# Системные логи
sudo journalctl -f

# Логи Docker
sudo journalctl -u docker.service -f
```

## 🆘 Устранение неполадок

### Частые проблемы

#### 1. Контейнеры не запускаются
```bash
# Проверяем логи
docker-compose -f docker-compose.production.yml logs

# Проверяем статус
docker-compose -f docker-compose.production.yml ps
```

#### 2. База данных недоступна
```bash
# Проверяем подключение к PostgreSQL
docker-compose -f docker-compose.production.yml exec postgres pg_isready -U postgres

# Проверяем логи PostgreSQL
docker-compose -f docker-compose.production.yml logs postgres
```

#### 3. API недоступен
```bash
# Проверяем статус backend
docker-compose -f docker-compose.production.yml ps backend

# Проверяем логи backend
docker-compose -f docker-compose.production.yml logs backend
```

#### 4. Фронтенд недоступен
```bash
# Проверяем статус frontend
docker-compose -f docker-compose.production.yml ps frontend

# Проверяем логи frontend
docker-compose -f docker-compose.production.yml logs frontend
```

### Полная переустановка
```bash
# Останавливаем все контейнеры
docker-compose -f docker-compose.production.yml down --volumes --remove-orphans

# Удаляем все образы
docker-compose -f docker-compose.production.yml down --rmi all

# Запускаем заново
./deploy.sh --clean
```

## 📞 Поддержка

Если у вас возникли проблемы с развертыванием:

1. Проверьте логи сервисов
2. Убедитесь, что все порты свободны
3. Проверьте настройки файрвола
4. Убедитесь, что Docker и Docker Compose установлены правильно

## 📝 Дополнительная информация

### Структура проекта
```
agb_passports/
├── docker-compose.production.yml    # Production конфигурация
├── Dockerfile.backend               # Backend образ
├── Dockerfile.frontend.production  # Frontend production образ
├── nginx.production.conf           # Nginx конфигурация
├── nginx.frontend.conf             # Frontend nginx конфигурация
├── init_database.sh                # Скрипт инициализации БД
├── deploy.sh                       # Скрипт развертывания
├── backup_clean_state_*.sql         # Бекап базы данных
└── .env.production                 # Переменные окружения
```

### Порты
- **80**: Nginx (основное приложение)
- **443**: Nginx HTTPS (если настроен SSL)
- **3000**: Frontend (внутренний)
- **8000**: Backend API
- **5432**: PostgreSQL (внутренний)

---

**Удачного развертывания! 🎉**

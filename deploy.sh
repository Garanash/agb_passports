#!/bin/bash

# Скрипт развертывания AGB Passports на сервере
# Использование: ./deploy.sh

set -e

echo "🚀 Развертывание AGB Passports на сервере..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Проверяем наличие Docker
if ! command -v docker &> /dev/null; then
    error "Docker не установлен!"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose не установлен!"
    exit 1
fi

success "Docker и Docker Compose найдены"

# Проверяем наличие необходимых файлов
REQUIRED_FILES=(
    "docker-compose.production.yml"
    "Dockerfile.backend"
    "Dockerfile.frontend.production"
    "nginx.production.conf"
    "nginx.frontend.conf"
    "backup_clean_state_20251022_213032.sql"
    "init_database.sh"
)

log "Проверка необходимых файлов..."
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        error "Файл $file не найден!"
        exit 1
    fi
done

success "Все необходимые файлы найдены"

# Создаем директории для логов и SSL
log "Создание необходимых директорий..."
mkdir -p logs
mkdir -p ssl
success "Директории созданы"

# Создаем файл окружения, если его нет
if [ ! -f ".env.production" ]; then
    log "Создание файла окружения..."
    cat > .env.production << EOF
# Production Environment Variables
POSTGRES_PASSWORD=agb_passports_2024_secure
SECRET_KEY=your-super-secret-key-change-in-production-$(openssl rand -hex 32)
API_URL=http://localhost:8000

# SSL Configuration (раскомментировать для HTTPS)
# SSL_CERT_PATH=/etc/nginx/ssl/cert.pem
# SSL_KEY_PATH=/etc/nginx/ssl/key.pem
EOF
    success "Файл .env.production создан"
    warning "Не забудьте изменить пароли и ключи в .env.production!"
fi

# Останавливаем существующие контейнеры
log "Остановка существующих контейнеров..."
docker-compose -f docker-compose.production.yml down --remove-orphans || true
success "Контейнеры остановлены"

# Удаляем старые образы (опционально)
if [ "$1" = "--clean" ]; then
    log "Очистка старых образов..."
    docker-compose -f docker-compose.production.yml down --rmi all --volumes --remove-orphans || true
    success "Старые образы удалены"
fi

# Собираем образы
log "Сборка Docker образов..."
docker-compose -f docker-compose.production.yml build --no-cache
success "Образы собраны"

# Запускаем сервисы
log "Запуск сервисов..."
docker-compose -f docker-compose.production.yml up -d
success "Сервисы запущены"

# Ждем запуска PostgreSQL
log "Ожидание запуска PostgreSQL..."
sleep 10

# Инициализируем базу данных
log "Инициализация базы данных..."
./init_database.sh

# Проверяем статус сервисов
log "Проверка статуса сервисов..."
docker-compose -f docker-compose.production.yml ps

# Проверяем доступность API
log "Проверка доступности API..."
sleep 5
if curl -f http://localhost:8000/docs > /dev/null 2>&1; then
    success "API доступен"
else
    warning "API недоступен, проверьте логи"
fi

# Проверяем доступность фронтенда
log "Проверка доступности фронтенда..."
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    success "Фронтенд доступен"
else
    warning "Фронтенд недоступен, проверьте логи"
fi

# Проверяем доступность через nginx
log "Проверка доступности через nginx..."
if curl -f http://localhost > /dev/null 2>&1; then
    success "Nginx доступен"
else
    warning "Nginx недоступен, проверьте логи"
fi

echo ""
success "🎉 Развертывание завершено!"
echo ""
echo "📋 Информация о развертывании:"
echo "   🌐 Приложение: http://localhost"
echo "   🔧 API: http://localhost:8000"
echo "   📚 API Docs: http://localhost:8000/docs"
echo "   🗄️  База данных: localhost:5432"
echo ""
echo "🔐 Данные для входа:"
echo "   Логин: admin"
echo "   Пароль: admin123"
echo ""
echo "📊 Полезные команды:"
echo "   Просмотр логов: docker-compose -f docker-compose.production.yml logs -f"
echo "   Остановка: docker-compose -f docker-compose.production.yml down"
echo "   Перезапуск: docker-compose -f docker-compose.production.yml restart"
echo "   Статус: docker-compose -f docker-compose.production.yml ps"
echo ""
echo "🔧 Настройка SSL (опционально):"
echo "   1. Поместите SSL сертификаты в директорию ssl/"
echo "   2. Раскомментируйте HTTPS секции в nginx.production.conf"
echo "   3. Перезапустите nginx: docker-compose -f docker-compose.production.yml restart nginx"
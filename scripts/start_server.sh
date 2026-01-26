#!/bin/bash

# Скрипт для запуска приложения на сервере

set -e

echo "🚀 Запуск приложения на сервере..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функции для вывода
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "ℹ️  $1"
}

# Проверяем, что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    error "Файл docker-compose.yml не найден!"
    exit 1
fi

# Определяем команду docker compose
DOCKER_COMPOSE_CMD="docker compose"
if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
fi

# Останавливаем старые контейнеры
info "Остановка старых контейнеров..."
$DOCKER_COMPOSE_CMD down 2>/dev/null || true
success "Старые контейнеры остановлены"

# Удаляем старые контейнеры с теми же именами (если есть)
info "Очистка старых контейнеров..."
docker rm -f agb_postgres agb_backend agb_frontend agb_nginx 2>/dev/null || true
success "Очистка завершена"

# Проверяем сеть
info "Проверка сети..."
if ! docker network ls | grep -q agb_network; then
    info "Создание сети agb_network..."
    docker network create agb_network 2>/dev/null || true
    success "Сеть создана"
else
    success "Сеть существует"
fi

# Собираем образы
info "Сборка Docker образов..."
$DOCKER_COMPOSE_CMD build --no-cache backend frontend 2>&1 | tail -20
success "Образы собраны"

# Запускаем PostgreSQL первым
info "Запуск PostgreSQL..."
$DOCKER_COMPOSE_CMD up -d postgres
success "PostgreSQL запущен"

# Ждем, пока PostgreSQL будет готов
info "Ожидание готовности PostgreSQL..."
for i in {1..30}; do
    if docker exec agb_postgres pg_isready -U postgres > /dev/null 2>&1; then
        success "PostgreSQL готов"
        break
    fi
    if [ $i -eq 30 ]; then
        error "PostgreSQL не запустился за 30 секунд"
        exit 1
    fi
    sleep 1
done

# Проверяем и устанавливаем пароль PostgreSQL
info "Проверка пароля PostgreSQL..."
docker exec agb_postgres psql -U postgres -c "ALTER ROLE postgres WITH PASSWORD 'password';" 2>/dev/null || true
success "Пароль PostgreSQL установлен"

# Запускаем backend
info "Запуск backend..."
$DOCKER_COMPOSE_CMD up -d backend
success "Backend запущен"

# Ждем немного для запуска backend
sleep 3

# Проверяем логи backend
info "Проверка логов backend..."
if docker logs agb_backend --tail 10 2>&1 | grep -q "error\|Error\|ERROR"; then
    warning "Обнаружены ошибки в логах backend:"
    docker logs agb_backend --tail 20
else
    success "Backend запущен без ошибок"
fi

# Запускаем frontend
info "Запуск frontend..."
$DOCKER_COMPOSE_CMD up -d frontend
success "Frontend запущен"

# Ждем сборки frontend
info "Ожидание сборки frontend (это может занять несколько минут)..."
for i in {1..60}; do
    if docker logs agb_frontend --tail 5 2>&1 | grep -q "ready\|started\|Local:"; then
        success "Frontend готов"
        break
    fi
    if [ $i -eq 60 ]; then
        warning "Frontend все еще запускается (это нормально для первого запуска)"
    fi
    sleep 2
done

# Запускаем nginx
info "Запуск nginx..."
$DOCKER_COMPOSE_CMD up -d nginx
success "Nginx запущен"

# Проверяем статус всех контейнеров
info "Проверка статуса контейнеров..."
sleep 2
$DOCKER_COMPOSE_CMD ps

# Проверяем здоровье контейнеров
info "Проверка здоровья контейнеров..."
HEALTHY=true

if ! docker ps | grep -q agb_postgres; then
    error "PostgreSQL не запущен"
    HEALTHY=false
fi

if ! docker ps | grep -q agb_backend; then
    error "Backend не запущен"
    HEALTHY=false
fi

if ! docker ps | grep -q agb_frontend; then
    error "Frontend не запущен"
    HEALTHY=false
fi

if ! docker ps | grep -q agb_nginx; then
    error "Nginx не запущен"
    HEALTHY=false
fi

if [ "$HEALTHY" = true ]; then
    success "Все контейнеры запущены!"
else
    error "Некоторые контейнеры не запущены. Проверьте логи:"
    echo "  docker logs agb_backend"
    echo "  docker logs agb_frontend"
    echo "  docker logs agb_nginx"
    exit 1
fi

# Проверяем доступность API
info "Проверка доступности API..."
sleep 3
if curl -f http://localhost:8000/docs > /dev/null 2>&1 || curl -f http://localhost:8000/health > /dev/null 2>&1; then
    success "API доступен на http://localhost:8000"
else
    warning "API может быть еще не готов. Проверьте логи: docker logs agb_backend"
fi

# Проверяем доступность frontend
info "Проверка доступности frontend..."
sleep 2
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    success "Frontend доступен на http://localhost:3000"
else
    warning "Frontend может быть еще не готов. Проверьте логи: docker logs agb_frontend"
fi

# Проверяем доступность через nginx
info "Проверка доступности через nginx..."
sleep 2
if curl -f http://localhost > /dev/null 2>&1; then
    success "Приложение доступно через nginx на http://localhost"
else
    warning "Nginx может быть еще не готов. Проверьте логи: docker logs agb_nginx"
fi

echo ""
success "Приложение запущено!"
echo ""
info "Полезные команды:"
echo "  Просмотр логов: $DOCKER_COMPOSE_CMD logs -f"
echo "  Остановка: $DOCKER_COMPOSE_CMD down"
echo "  Перезапуск: $DOCKER_COMPOSE_CMD restart"
echo "  Статус: $DOCKER_COMPOSE_CMD ps"
echo ""
info "Проверка логов отдельных сервисов:"
echo "  docker logs agb_backend --tail 50"
echo "  docker logs agb_frontend --tail 50"
echo "  docker logs agb_nginx --tail 50"
echo ""

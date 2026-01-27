#!/bin/bash

# Полный деплой проекта из git на сервер
# Удаляет все кроме бекапов, стягивает проект, собирает и восстанавливает БД

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
GIT_REPO_URL="${GIT_REPO_URL:-}"  # Можно указать через переменную окружения

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Полный деплой проекта из Git${NC}"
echo ""

# Проверяем наличие sshpass
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}❌ sshpass не установлен. Установите: brew install hudochenkov/sshpass/sshpass${NC}"
    exit 1
fi

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

echo -e "${YELLOW}📋 Шаг 1: Сохранение бекапов...${NC}"
# Сохраняем бекапы во временную директорию
ssh_exec "mkdir -p /tmp/agb_backups && cp -r $SERVER_PATH/backup_*.sql /tmp/agb_backups/ 2>/dev/null || true"
BACKUP_COUNT=$(ssh_exec "ls -1 /tmp/agb_backups/*.sql 2>/dev/null | wc -l" | tr -d ' ')
echo -e "${GREEN}✅ Сохранено $BACKUP_COUNT бекапов${NC}"
echo ""

echo -e "${YELLOW}📋 Шаг 2: Остановка контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose -f docker-compose.production.yml down 2>/dev/null || docker-compose -f docker-compose.production.yml down 2>/dev/null || true"
echo -e "${GREEN}✅ Контейнеры остановлены${NC}"
echo ""

echo -e "${YELLOW}📋 Шаг 3: Удаление старого проекта (кроме бекапов)...${NC}"
# Удаляем все кроме бекапов и директории .git
ssh_exec "cd $SERVER_PATH && find . -mindepth 1 -maxdepth 1 ! -name 'backup_*.sql' ! -name '.git' -exec rm -rf {} + 2>/dev/null || true"
echo -e "${GREEN}✅ Старый проект удален${NC}"
echo ""

echo -e "${YELLOW}📋 Шаг 4: Получение проекта из Git...${NC}"
# Если есть .git, делаем pull, иначе клонируем
if ssh_exec "test -d $SERVER_PATH/.git"; then
    echo "Обновление существующего репозитория..."
    ssh_exec "cd $SERVER_PATH && git fetch --all && git reset --hard origin/main || git reset --hard origin/master"
    ssh_exec "cd $SERVER_PATH && git pull origin main || git pull origin master"
else
    if [ -z "$GIT_REPO_URL" ]; then
        echo -e "${RED}❌ GIT_REPO_URL не указан и .git не найден. Укажите URL репозитория:${NC}"
        echo "export GIT_REPO_URL='your-repo-url' && $0"
        exit 1
    fi
    echo "Клонирование репозитория..."
    ssh_exec "rm -rf $SERVER_PATH && git clone $GIT_REPO_URL $SERVER_PATH"
fi
echo -e "${GREEN}✅ Проект получен из Git${NC}"
echo ""

echo -e "${YELLOW}📋 Шаг 5: Восстановление бекапов...${NC}"
# Копируем бекапы обратно
ssh_exec "cp /tmp/agb_backups/*.sql $SERVER_PATH/ 2>/dev/null || true"
ssh_exec "rm -rf /tmp/agb_backups"
echo -e "${GREEN}✅ Бекапы восстановлены${NC}"
echo ""

echo -e "${YELLOW}📋 Шаг 6: Копирование необходимых файлов...${NC}"
# Копируем .env.prod если есть локально
if [ -f ".env.prod" ]; then
    scp_copy ".env.prod" "$SERVER:$SERVER_PATH/.env.prod"
    echo -e "${GREEN}✅ .env.prod скопирован${NC}"
else
    echo -e "${YELLOW}⚠️ .env.prod не найден локально, используйте существующий на сервере${NC}"
fi

# Копируем шаблоны если нужно
if [ -d "templates" ]; then
    ssh_exec "mkdir -p $SERVER_PATH/templates"
    scp_copy -r "templates/"* "$SERVER:$SERVER_PATH/templates/"
    echo -e "${GREEN}✅ Шаблоны скопированы${NC}"
fi

if [ -d "backend/utils/templates" ]; then
    ssh_exec "mkdir -p $SERVER_PATH/backend/utils/templates"
    scp_copy -r "backend/utils/templates/"* "$SERVER:$SERVER_PATH/backend/utils/templates/"
    echo -e "${GREEN}✅ Backend шаблоны скопированы${NC}"
fi
echo ""

echo -e "${YELLOW}📋 Шаг 7: Сборка и запуск контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose -f docker-compose.production.yml up -d --build"
echo -e "${GREEN}✅ Контейнеры запущены${NC}"
echo ""

echo -e "${YELLOW}⏳ Ожидание запуска сервисов (20 секунд)...${NC}"
sleep 20
echo ""

echo -e "${YELLOW}📋 Шаг 8: Восстановление базы данных из бекапа...${NC}"
# Находим последний бекап
LATEST_BACKUP=$(ssh_exec "ls -t $SERVER_PATH/backup_*.sql 2>/dev/null | head -1" | tr -d '\r\n')

if [ -n "$LATEST_BACKUP" ] && [ "$LATEST_BACKUP" != "" ]; then
    echo "Используется бекап: $LATEST_BACKUP"
    
    # Ждем готовности PostgreSQL
    echo "Ожидание готовности PostgreSQL..."
    for i in {1..30}; do
        if ssh_exec "docker exec agb_postgres_prod pg_isready -U postgres >/dev/null 2>&1"; then
            break
        fi
        sleep 1
    done
    
    # Восстанавливаем БД
    echo "Восстановление базы данных..."
    ssh_exec "docker exec -i agb_postgres_prod psql -U postgres -d agb_passports < $LATEST_BACKUP" || {
        echo -e "${YELLOW}⚠️ Прямое восстановление не удалось, пробуем через файл...${NC}"
        BACKUP_NAME=$(basename "$LATEST_BACKUP")
        ssh_exec "docker cp $LATEST_BACKUP agb_postgres_prod:/tmp/$BACKUP_NAME"
        ssh_exec "docker exec agb_postgres_prod psql -U postgres -d agb_passports -f /tmp/$BACKUP_NAME"
        ssh_exec "docker exec agb_postgres_prod rm /tmp/$BACKUP_NAME"
    }
    echo -e "${GREEN}✅ База данных восстановлена${NC}"
else
    echo -e "${YELLOW}⚠️ Бекапы не найдены, база данных будет инициализирована заново${NC}"
fi
echo ""

echo -e "${YELLOW}📋 Шаг 9: Проверка статуса...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose -f docker-compose.production.yml ps"
echo ""

echo -e "${YELLOW}📋 Шаг 10: Проверка логов...${NC}"
echo -e "${BLUE}Backend logs (последние 20 строк):${NC}"
ssh_exec "docker logs agb_backend_prod --tail 20 2>&1 | tail -20"
echo ""

echo -e "${BLUE}Frontend logs (последние 20 строк):${NC}"
ssh_exec "docker logs agb_frontend_prod --tail 20 2>&1 | tail -20"
echo ""

echo -e "${YELLOW}📋 Шаг 11: Проверка доступности...${NC}"
sleep 5
HEALTH=$(curl -s http://185.247.17.188/health 2>/dev/null || echo "ERROR")
if [ "$HEALTH" = "healthy" ]; then
    echo -e "${GREEN}✅ Health check: OK${NC}"
else
    echo -e "${YELLOW}⚠️ Health check: $HEALTH${NC}"
fi

MAIN_PAGE=$(curl -s -o /dev/null -w "%{http_code}" http://185.247.17.188/ 2>/dev/null || echo "000")
if [ "$MAIN_PAGE" = "200" ]; then
    echo -e "${GREEN}✅ Главная страница: OK (200)${NC}"
else
    echo -e "${YELLOW}⚠️ Главная страница: HTTP $MAIN_PAGE${NC}"
fi

API=$(curl -s -o /dev/null -w "%{http_code}" http://185.247.17.188/api/v1/ 2>/dev/null || echo "000")
if [ "$API" = "200" ] || [ "$API" = "404" ]; then
    echo -e "${GREEN}✅ API: OK (HTTP $API)${NC}"
else
    echo -e "${YELLOW}⚠️ API: HTTP $API${NC}"
fi
echo ""

echo -e "${GREEN}✅ Деплой завершен!${NC}"
echo ""
echo -e "${BLUE}Проверьте приложение:${NC}"
echo "  - Frontend: http://185.247.17.188"
echo "  - API: http://185.247.17.188/api/v1/"
echo "  - Health: http://185.247.17.188/health"
echo ""
echo -e "${BLUE}Для просмотра логов:${NC}"
echo "  ssh $SERVER 'cd $SERVER_PATH && docker compose -f docker-compose.production.yml logs --tail 50'"

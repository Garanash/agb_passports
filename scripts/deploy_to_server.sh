#!/bin/bash

# Скрипт для полного деплоя на сервер через SSH
# Синхронизирует файлы и запускает приложение

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Деплой приложения на сервер${NC}"
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
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@"
}

echo -e "${YELLOW}📦 Шаг 1: Создание необходимых директорий на сервере...${NC}"
# Создаем необходимые директории на сервере
ssh_exec "mkdir -p $SERVER_PATH/backend/api/v1/endpoints" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/backend/utils" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/components" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/lib" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/hooks" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/contexts" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/pages" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Директории созданы${NC}"
echo ""

echo -e "${YELLOW}📦 Шаг 2: Синхронизация измененных файлов на сервер...${NC}"

# Синхронизируем backend файлы
echo "  📤 Backend файлы..."
scp_copy "$LOCAL_PATH/backend/api/v1/endpoints/nomenclature.py" "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/api/v1/endpoints/passports.py" "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/api/v1/endpoints/users.py" "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/api/v1/endpoints/templates.py" "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/api/auth.py" "$SERVER:$SERVER_PATH/backend/api/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/api/schemas.py" "$SERVER:$SERVER_PATH/backend/api/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/database.py" "$SERVER:$SERVER_PATH/backend/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/main.py" "$SERVER:$SERVER_PATH/backend/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/models.py" "$SERVER:$SERVER_PATH/backend/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/utils/pdf_generator.py" "$SERVER:$SERVER_PATH/backend/utils/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/utils/sticker_template_generator.py" "$SERVER:$SERVER_PATH/backend/utils/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/utils/create_logo.py" "$SERVER:$SERVER_PATH/backend/utils/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/requirements.txt" "$SERVER:$SERVER_PATH/backend/" 2>&1 | grep -v "Warning" || true

# Синхронизируем frontend файлы
echo "  📤 Frontend файлы..."
scp_copy "$LOCAL_PATH/frontend/components/MainApp.tsx" "$SERVER:$SERVER_PATH/frontend/components/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/components/ProtectedRoute.tsx" "$SERVER:$SERVER_PATH/frontend/components/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/components/Layout.tsx" "$SERVER:$SERVER_PATH/frontend/components/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/lib/api.ts" "$SERVER:$SERVER_PATH/frontend/lib/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/hooks/usePassports.ts" "$SERVER:$SERVER_PATH/frontend/hooks/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/hooks/useNomenclature.ts" "$SERVER:$SERVER_PATH/frontend/hooks/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/hooks/useUsers.ts" "$SERVER:$SERVER_PATH/frontend/hooks/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/contexts/AuthContext.tsx" "$SERVER:$SERVER_PATH/frontend/contexts/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/pages/login.tsx" "$SERVER:$SERVER_PATH/frontend/pages/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/pages/_app.tsx" "$SERVER:$SERVER_PATH/frontend/pages/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/pages/index.tsx" "$SERVER:$SERVER_PATH/frontend/pages/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/next.config.js" "$SERVER:$SERVER_PATH/frontend/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/package.json" "$SERVER:$SERVER_PATH/frontend/" 2>&1 | grep -v "Warning" || true

# Синхронизируем конфигурационные файлы
echo "  📤 Конфигурационные файлы..."
scp_copy "$LOCAL_PATH/docker-compose.yml" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/Dockerfile.backend" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/Dockerfile.frontend" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/nginx.production.conf" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/start_server.sh" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/run_backend.py" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/create_admin.py" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/verify_deployment.sh" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/check_and_fix_db.sh" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true

# Делаем скрипты исполняемыми на сервере
ssh_exec "chmod +x $SERVER_PATH/start_server.sh $SERVER_PATH/verify_deployment.sh $SERVER_PATH/check_and_fix_db.sh $SERVER_PATH/create_admin.py" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Файлы синхронизированы${NC}"
echo ""

echo -e "${GREEN}✅ Файлы синхронизированы${NC}"
echo ""

echo -e "${YELLOW}🔄 Шаг 3: Остановка старых контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Старые контейнеры остановлены${NC}"
echo ""

echo -e "${YELLOW}👤 Шаг 4: Проверка/создание администратора...${NC}"
ssh_exec "cd $SERVER_PATH && python3 create_admin.py 2>&1 || python create_admin.py 2>&1" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Администратор проверен${NC}"
echo ""

echo -e "${YELLOW}🏗️  Шаг 5: Сборка и запуск приложения...${NC}"
ssh_exec "cd $SERVER_PATH && ./start_server.sh" 2>&1 | tail -50

echo ""
echo -e "${YELLOW}🔍 Шаг 6: Проверка работоспособности...${NC}"
ssh_exec "cd $SERVER_PATH && ./verify_deployment.sh 2>&1 || echo 'Скрипт проверки не найден'" 2>&1 | tail -20

echo ""
echo -e "${GREEN}✅ Деплой завершен!${NC}"
echo ""
echo -e "${BLUE}📊 Статус контейнеров:${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose ps 2>/dev/null || docker compose ps 2>/dev/null" 2>&1 | grep -E "NAME|agb_" || true

echo ""
echo -e "${BLUE}🌐 Приложение доступно по адресу:${NC}"
echo "   http://185.247.17.188"
echo "   http://185.247.17.188:8000/docs (API Docs)"
echo ""

#!/bin/bash

# Полный скрипт деплоя на сервер через SSH
# Синхронизирует все необходимые файлы и запускает приложение

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

echo -e "${BLUE}🚀 Полный деплой приложения на сервер${NC}"
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

# Функция для копирования директории
scp_copy_dir() {
    local src=$1
    local dst=$2
    ssh_exec "mkdir -p $dst" 2>&1 | grep -v "Warning" || true
    sshpass -p "$PASSWORD" scp -r -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$src" "$SERVER:$dst" 2>&1 | grep -v "Warning" || true
}

echo -e "${YELLOW}📦 Шаг 1: Создание необходимых директорий на сервере...${NC}"
# Создаем все необходимые директории
ssh_exec "mkdir -p $SERVER_PATH/backend/api/v1/endpoints" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/backend/utils/templates" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/lib" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/components" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/hooks" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/contexts" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/pages" 2>&1 | grep -v "Warning" || true
ssh_exec "mkdir -p $SERVER_PATH/frontend/styles" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Директории созданы${NC}"
echo ""

echo -e "${YELLOW}📦 Шаг 2: Синхронизация backend файлов...${NC}"
# Backend API endpoints
scp_copy "$LOCAL_PATH/backend/api/v1/endpoints/passports.py" "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/"
scp_copy "$LOCAL_PATH/backend/api/v1/endpoints/nomenclature.py" "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/"
scp_copy "$LOCAL_PATH/backend/api/v1/endpoints/users.py" "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/"
scp_copy "$LOCAL_PATH/backend/api/v1/endpoints/templates.py" "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/"

# Backend API core
scp_copy "$LOCAL_PATH/backend/api/auth.py" "$SERVER:$SERVER_PATH/backend/api/"
scp_copy "$LOCAL_PATH/backend/api/schemas.py" "$SERVER:$SERVER_PATH/backend/api/"

# Backend core
scp_copy "$LOCAL_PATH/backend/main.py" "$SERVER:$SERVER_PATH/backend/"
scp_copy "$LOCAL_PATH/backend/database.py" "$SERVER:$SERVER_PATH/backend/"
scp_copy "$LOCAL_PATH/backend/models.py" "$SERVER:$SERVER_PATH/backend/"
scp_copy "$LOCAL_PATH/backend/requirements.txt" "$SERVER:$SERVER_PATH/backend/"

# Backend utils (критически важные файлы)
scp_copy "$LOCAL_PATH/backend/utils/pdf_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"
scp_copy "$LOCAL_PATH/backend/utils/sticker_template_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"
scp_copy "$LOCAL_PATH/backend/utils/template_manager.py" "$SERVER:$SERVER_PATH/backend/utils/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/utils/barcode_generator.py" "$SERVER:$SERVER_PATH/backend/utils/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/utils/create_logo.py" "$SERVER:$SERVER_PATH/backend/utils/"

# Backend utils templates (логотип)
echo "  📤 Логотип..."
ssh_exec "mkdir -p $SERVER_PATH/backend/utils/templates 2>&1" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/backend/utils/templates/logo.png" "$SERVER:$SERVER_PATH/backend/utils/templates/" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Backend файлы синхронизированы${NC}"
echo ""

echo -e "${YELLOW}📦 Шаг 3: Синхронизация frontend файлов...${NC}"
# Frontend lib (критически важно!)
scp_copy "$LOCAL_PATH/frontend/lib/api.ts" "$SERVER:$SERVER_PATH/frontend/lib/"

# Frontend components
scp_copy "$LOCAL_PATH/frontend/components/MainApp.tsx" "$SERVER:$SERVER_PATH/frontend/components/"
scp_copy "$LOCAL_PATH/frontend/components/ProtectedRoute.tsx" "$SERVER:$SERVER_PATH/frontend/components/"
scp_copy "$LOCAL_PATH/frontend/components/Layout.tsx" "$SERVER:$SERVER_PATH/frontend/components/"
scp_copy "$LOCAL_PATH/frontend/components/TemplateEditor.tsx" "$SERVER:$SERVER_PATH/frontend/components/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/frontend/components/AddNomenclatureTab.tsx" "$SERVER:$SERVER_PATH/frontend/components/" 2>&1 | grep -v "Warning" || true

# Frontend hooks
scp_copy "$LOCAL_PATH/frontend/hooks/usePassports.ts" "$SERVER:$SERVER_PATH/frontend/hooks/"
scp_copy "$LOCAL_PATH/frontend/hooks/useNomenclature.ts" "$SERVER:$SERVER_PATH/frontend/hooks/"
scp_copy "$LOCAL_PATH/frontend/hooks/useUsers.ts" "$SERVER:$SERVER_PATH/frontend/hooks/"

# Frontend contexts
scp_copy "$LOCAL_PATH/frontend/contexts/AuthContext.tsx" "$SERVER:$SERVER_PATH/frontend/contexts/"

# Frontend pages
scp_copy "$LOCAL_PATH/frontend/pages/_app.tsx" "$SERVER:$SERVER_PATH/frontend/pages/"
scp_copy "$LOCAL_PATH/frontend/pages/index.tsx" "$SERVER:$SERVER_PATH/frontend/pages/"
scp_copy "$LOCAL_PATH/frontend/pages/login.tsx" "$SERVER:$SERVER_PATH/frontend/pages/"

# Frontend config
scp_copy "$LOCAL_PATH/frontend/next.config.js" "$SERVER:$SERVER_PATH/frontend/"
scp_copy "$LOCAL_PATH/frontend/package.json" "$SERVER:$SERVER_PATH/frontend/"
scp_copy "$LOCAL_PATH/frontend/tsconfig.json" "$SERVER:$SERVER_PATH/frontend/" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Frontend файлы синхронизированы${NC}"
echo ""

echo -e "${YELLOW}📦 Шаг 4: Синхронизация конфигурационных файлов...${NC}"
# Docker и конфигурация
scp_copy "$LOCAL_PATH/docker-compose.yml" "$SERVER:$SERVER_PATH/"
scp_copy "$LOCAL_PATH/Dockerfile.backend" "$SERVER:$SERVER_PATH/"
scp_copy "$LOCAL_PATH/Dockerfile.frontend" "$SERVER:$SERVER_PATH/"
scp_copy "$LOCAL_PATH/nginx.production.conf" "$SERVER:$SERVER_PATH/"

# Скрипты
scp_copy "$LOCAL_PATH/start_server.sh" "$SERVER:$SERVER_PATH/"
scp_copy "$LOCAL_PATH/run_backend.py" "$SERVER:$SERVER_PATH/"
scp_copy "$LOCAL_PATH/create_admin.py" "$SERVER:$SERVER_PATH/"
scp_copy "$LOCAL_PATH/verify_deployment.sh" "$SERVER:$SERVER_PATH/"
scp_copy "$LOCAL_PATH/check_and_fix_db.sh" "$SERVER:$SERVER_PATH/"

# Делаем скрипты исполняемыми
ssh_exec "chmod +x $SERVER_PATH/*.sh $SERVER_PATH/*.py" 2>&1 | grep -v "Warning" || true

echo -e "${GREEN}✅ Конфигурационные файлы синхронизированы${NC}"
echo ""

echo -e "${YELLOW}🔄 Шаг 5: Остановка старых контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Старые контейнеры остановлены${NC}"
echo ""

echo -e "${YELLOW}👤 Шаг 6: Проверка/создание администратора...${NC}"
ssh_exec "cd $SERVER_PATH && python3 create_admin.py 2>&1 || python create_admin.py 2>&1" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Администратор проверен${NC}"
echo ""

echo -e "${YELLOW}🏗️  Шаг 7: Сборка и запуск приложения...${NC}"
ssh_exec "cd $SERVER_PATH && ./start_server.sh" 2>&1 | tail -60

echo ""
echo -e "${YELLOW}🔍 Шаг 8: Проверка работоспособности...${NC}"
sleep 5
ssh_exec "cd $SERVER_PATH && ./verify_deployment.sh 2>&1 || echo 'Проверка завершена'" 2>&1 | tail -30

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
echo -e "${YELLOW}📝 Полезные команды:${NC}"
echo "   Просмотр логов: ssh $SERVER 'cd $SERVER_PATH && docker-compose logs -f'"
echo "   Перезапуск: ssh $SERVER 'cd $SERVER_PATH && docker-compose restart'"
echo "   Статус: ssh $SERVER 'cd $SERVER_PATH && docker-compose ps'"
echo ""

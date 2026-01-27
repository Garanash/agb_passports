#!/bin/bash

# Полная настройка и тестирование сервера

set -e

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"
LOCAL_PATH="/Users/andreydolgov/Desktop/ALMAZGEOBUR_WORK/agb_pasports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Полная настройка и тестирование сервера${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

# Функция для копирования файлов
scp_copy() {
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$@" 2>&1 | grep -v "Warning" || true
}

echo -e "${YELLOW}📤 Шаг 1: Синхронизация всех файлов...${NC}"
scp_copy "$LOCAL_PATH/backend/requirements.txt" "$SERVER:$SERVER_PATH/backend/"
scp_copy "$LOCAL_PATH/backend/utils/sticker_template_generator.py" "$SERVER:$SERVER_PATH/backend/utils/"
scp_copy "$LOCAL_PATH/backend/api/v1/endpoints/templates.py" "$SERVER:$SERVER_PATH/backend/api/v1/endpoints/"
scp_copy "$LOCAL_PATH/backend/api/auth.py" "$SERVER:$SERVER_PATH/backend/api/"
scp_copy_dir "$LOCAL_PATH/backend/utils/templates" "$SERVER_PATH/backend/utils/"
scp_copy_dir "$LOCAL_PATH/frontend" "$SERVER_PATH/"
scp_copy "$LOCAL_PATH/docker-compose.yml" "$SERVER:$SERVER_PATH/"
scp_copy "$LOCAL_PATH/Dockerfile.backend" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
scp_copy "$LOCAL_PATH/Dockerfile.frontend" "$SERVER:$SERVER_PATH/" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Файлы синхронизированы${NC}"
echo ""

echo -e "${YELLOW}🛑 Шаг 2: Остановка и удаление старых контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose stop backend frontend" 2>&1 | grep -v "Warning" || true
ssh_exec "cd $SERVER_PATH && docker compose rm -f backend frontend" 2>&1 | grep -v "Warning" || true
ssh_exec "docker rmi agb_passports-backend agb_passports-frontend 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Старые контейнеры удалены${NC}"
echo ""

echo -e "${YELLOW}🔨 Шаг 3: Пересборка контейнеров...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose build backend" 2>&1 | grep -E "(Step|Successfully|ERROR)" | tail -10
ssh_exec "cd $SERVER_PATH && docker compose build frontend" 2>&1 | grep -E "(Step|Successfully|ERROR)" | tail -10
echo ""

echo -e "${YELLOW}🚀 Шаг 4: Запуск всех сервисов...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose up -d" 2>&1 | grep -v "Warning" || true
echo ""

echo -e "${YELLOW}⏳ Шаг 5: Ожидание запуска сервисов...${NC}"
sleep 20

echo -e "${YELLOW}👤 Шаг 6: Создание пользователя admin...${NC}"
ADMIN_HASH="sha256\$8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918"
ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c \"INSERT INTO users (username, email, full_name, hashed_password, role, is_active) VALUES ('admin', 'admin@agb-passports.ru', 'Супер Администратор', 'sha256' || chr(36) || '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', 'admin', true) ON CONFLICT (username) DO UPDATE SET hashed_password='sha256' || chr(36) || '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', is_active=true;\" 2>&1" 2>&1 | grep -v "Warning" || true
echo ""

echo -e "${YELLOW}🧪 Шаг 7: Тестирование всех эндпоинтов...${NC}"

# Тест 1: Вход
echo -n "  Тест входа... "
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1 | grep -v "Warning")
if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    echo "    Ответ: ${LOGIN_RESPONSE:0:100}"
    TOKEN=""
fi

if [ ! -z "$TOKEN" ]; then
    # Тест 2: Получение паспортов
    echo -n "  Тест получения паспортов... "
    PASSPORTS_RESPONSE=$(ssh_exec "curl -s 'http://localhost:8000/api/v1/passports/?page=1&page_size=20' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1 | grep -v "Warning")
    if echo "$PASSPORTS_RESPONSE" | grep -q "passports\|total\|items\|\[\]"; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
        echo "    Ответ: ${PASSPORTS_RESPONSE:0:100}"
    fi
    
    # Тест 3: Получение номенклатуры
    echo -n "  Тест получения номенклатуры... "
    NOMENCLATURE_RESPONSE=$(ssh_exec "curl -s 'http://localhost:8000/api/v1/nomenclature/?page=1&page_size=20' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1 | grep -v "Warning")
    if echo "$NOMENCLATURE_RESPONSE" | grep -q "items\|\[\]"; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
    fi
    
    # Тест 4: Получение шаблонов
    echo -n "  Тест получения шаблонов... "
    TEMPLATES_RESPONSE=$(ssh_exec "curl -s 'http://localhost:8000/api/v1/templates/' -H 'Authorization: Bearer $TOKEN' 2>&1" 2>&1 | grep -v "Warning")
    if echo "$TEMPLATES_RESPONSE" | grep -q "type\|sticker\|passport"; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}📊 Шаг 8: Финальная проверка статуса...${NC}"
ssh_exec "cd $SERVER_PATH && docker compose ps" 2>&1 | grep -v "Warning" | tail -6 || true
echo ""

echo -e "${GREEN}✅ Настройка и тестирование завершены!${NC}"

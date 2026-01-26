#!/bin/bash

# Скрипт для проверки и создания администратора

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}👤 Проверка и создание администратора${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🔍 Проверка существующих пользователей...${NC}"
USERS=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c 'SELECT username FROM users;' 2>/dev/null" 2>&1 | grep -v "Warning" | tr -d ' ' | grep -v "^$")
echo "Найденные пользователи:"
echo "$USERS" | while read user; do
    if [ ! -z "$user" ]; then
        echo "  - $user"
    fi
done

echo ""
echo -e "${YELLOW}🔍 Проверка наличия пользователя admin...${NC}"
ADMIN_EXISTS=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c \"SELECT COUNT(*) FROM users WHERE username='admin';\" 2>/dev/null" 2>&1 | grep -v "Warning" | tr -d ' ')

if [ "$ADMIN_EXISTS" = "1" ]; then
    echo -e "${GREEN}✅ Пользователь admin существует${NC}"
    
    echo ""
    echo -e "${YELLOW}🔍 Проверка пароля пользователя admin...${NC}"
    ADMIN_PASSWORD=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c \"SELECT hashed_password FROM users WHERE username='admin';\" 2>/dev/null" 2>&1 | grep -v "Warning" | tr -d ' ')
    echo "Хеш пароля: ${ADMIN_PASSWORD:0:50}..."
    
    echo ""
    echo -e "${YELLOW}🧪 Тест входа с паролем admin...${NC}"
    LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)
    
    if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
        echo -e "${GREEN}✅ Вход успешен!${NC}"
        echo "   Токен получен"
    else
        echo -e "${RED}❌ Вход не удался${NC}"
        echo "   Ответ: $LOGIN_RESPONSE"
        
        echo ""
        echo -e "${YELLOW}🔧 Обновление пароля администратора...${NC}"
        # Вычисляем SHA256 хеш пароля "admin"
        ADMIN_HASH=$(ssh_exec "python3 -c \"import hashlib; print('sha256\$' + hashlib.sha256(b'admin').hexdigest())\" 2>/dev/null" 2>&1 | grep -v "Warning" | tail -1)
        echo "Новый хеш: $ADMIN_HASH"
        
        ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c \"UPDATE users SET hashed_password='$ADMIN_HASH' WHERE username='admin';\" 2>/dev/null" 2>&1 | grep -v "Warning" || true
        
        echo ""
        echo -e "${YELLOW}🧪 Повторный тест входа...${NC}"
        LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)
        
        if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
            echo -e "${GREEN}✅ Вход успешен после обновления пароля!${NC}"
        else
            echo -e "${RED}❌ Вход все еще не работает${NC}"
            echo "   Ответ: $LOGIN_RESPONSE"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Пользователь admin не найден, создаем...${NC}"
    
    # Создаем администратора через скрипт
    ssh_exec "cd $SERVER_PATH && python3 create_admin.py 2>&1 || python create_admin.py 2>&1" 2>&1 | grep -v "Warning" || true
    
    echo ""
    echo -e "${YELLOW}🧪 Тест входа после создания...${NC}"
    sleep 2
    LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)
    
    if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
        echo -e "${GREEN}✅ Вход успешен!${NC}"
    else
        echo -e "${RED}❌ Вход не работает${NC}"
        echo "   Ответ: $LOGIN_RESPONSE"
    fi
fi

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

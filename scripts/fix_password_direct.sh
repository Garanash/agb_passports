#!/bin/bash

# Скрипт для прямого исправления пароля через Python

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Прямое исправление пароля через Python${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🐍 Создание Python скрипта для обновления пароля...${NC}"
ssh_exec "cat > /tmp/fix_password.py << 'ENDPYTHON'
import hashlib
import psycopg2

# Вычисляем правильный хеш
password = 'admin'
hashed = 'sha256\$' + hashlib.sha256(password.encode()).hexdigest()

# Подключаемся к БД
conn = psycopg2.connect(
    host='postgres',
    port=5432,
    database='agb_passports',
    user='postgres',
    password='password'
)

cur = conn.cursor()
cur.execute(\"UPDATE users SET hashed_password=%s WHERE username='admin'\", (hashed,))
conn.commit()
cur.close()
conn.close()

print(f'Пароль обновлен: {hashed}')
ENDPYTHON
" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔧 Выполнение скрипта в контейнере backend...${NC}"
ssh_exec "docker exec agb_backend python3 /tmp/fix_password.py 2>&1 || docker exec -i agb_backend sh -c 'cat > /tmp/fix_password.py' < /tmp/fix_password.py && docker exec agb_backend python3 /tmp/fix_password.py 2>&1" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${YELLOW}🔍 Проверка хеша в базе данных...${NC}"
NEW_HASH=$(ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -t -c \"SELECT hashed_password FROM users WHERE username='admin';\" 2>/dev/null" 2>&1 | grep -v "Warning" | tr -d ' ')
echo "Хеш в базе: $NEW_HASH"

echo ""
echo -e "${YELLOW}🧪 Тест входа...${NC}"
LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✅ Вход успешен!${NC}"
    echo ""
    echo "Ответ сервера:"
    echo "$LOGIN_RESPONSE" | python3 -m json.tool 2>/dev/null | head -15 || echo "$LOGIN_RESPONSE" | head -5
    echo ""
    echo -e "${GREEN}🎉 Проблема решена! Теперь можно войти в приложение.${NC}"
else
    echo -e "${RED}❌ Вход не работает${NC}"
    echo "   Ответ: $LOGIN_RESPONSE"
    
    echo ""
    echo -e "${YELLOW}🔍 Попробуем через SQL с экранированием...${NC}"
    # Пробуем через SQL с двойным экранированием
    ssh_exec "docker exec agb_postgres psql -U postgres -d agb_passports -c \"UPDATE users SET hashed_password='sha256\\\$8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918' WHERE username='admin';\" 2>/dev/null" 2>&1 | grep -v "Warning" || true
    
    echo ""
    echo -e "${YELLOW}🧪 Повторный тест входа...${NC}"
    LOGIN_RESPONSE=$(ssh_exec "curl -s -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin\"}' 2>&1" 2>&1)
    
    if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
        echo -e "${GREEN}✅ Вход успешен после SQL обновления!${NC}"
    else
        echo -e "${RED}❌ Вход все еще не работает${NC}"
        echo "   Ответ: $LOGIN_RESPONSE"
    fi
fi

echo ""
echo -e "${GREEN}✅ Проверка завершена!${NC}"
echo ""

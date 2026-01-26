#!/bin/bash

# Скрипт для очистки служебных файлов macOS на сервере

SERVER="root@185.247.17.188"
PASSWORD="nnUQ3Q7wr2,AQ6"
SERVER_PATH="/root/agb_passports"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧹 Очистка служебных файлов macOS на сервере${NC}"
echo ""

# Функция для выполнения команд на сервере
ssh_exec() {
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SERVER" "$@"
}

echo -e "${YELLOW}🗑️  Удаление служебных файлов macOS...${NC}"
ssh_exec "cd $SERVER_PATH && find frontend -name '._*' -type f -delete 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
ssh_exec "cd $SERVER_PATH && find frontend -name '.DS_Store' -type f -delete 2>/dev/null || true" 2>&1 | grep -v "Warning" || true
echo -e "${GREEN}✅ Служебные файлы удалены${NC}"
echo ""

echo -e "${YELLOW}🔍 Проверка наличия проблемных файлов...${NC}"
ssh_exec "cd $SERVER_PATH && find frontend/pages -name '._*' -type f 2>/dev/null || echo 'Проблемных файлов не найдено'" 2>&1 | grep -v "Warning" || true

echo ""
echo -e "${GREEN}✅ Очистка завершена${NC}"
echo ""

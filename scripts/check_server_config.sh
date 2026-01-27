#!/bin/bash

# Скрипт проверки конфигурации сервера

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Проверка конфигурации сервера${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Проверка файлов шаблонов
echo -e "${YELLOW}📋 Проверка файлов шаблонов...${NC}"

if [ -f "backend/utils/templates/sticker_template.xlsx" ]; then
    echo -e "${GREEN}✅ sticker_template.xlsx найден${NC}"
else
    echo -e "${RED}❌ sticker_template.xlsx не найден${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "backend/utils/templates/sticker_template.docx" ]; then
    echo -e "${GREEN}✅ sticker_template.docx найден${NC}"
else
    echo -e "${YELLOW}⚠️ sticker_template.docx не найден (не критично)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -f "backend/utils/templates/logo.png" ]; then
    echo -e "${GREEN}✅ logo.png найден${NC}"
else
    echo -e "${RED}❌ logo.png не найден${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "templates/sticker_template.xlsx" ] || [ -f "templates/sticker_template.docx" ]; then
    echo -e "${GREEN}✅ Шаблоны в templates/ найдены${NC}"
else
    echo -e "${YELLOW}⚠️ Шаблоны в templates/ не найдены (будут созданы при первом использовании)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# Проверка docker-compose.production.yml
echo -e "${YELLOW}🐳 Проверка docker-compose.production.yml...${NC}"

if grep -q "ASYNC_DATABASE_URL" docker-compose.production.yml; then
    echo -e "${GREEN}✅ ASYNC_DATABASE_URL настроен${NC}"
else
    echo -e "${RED}❌ ASYNC_DATABASE_URL не настроен${NC}"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "/app/templates" docker-compose.production.yml; then
    echo -e "${GREEN}✅ Монтирование /app/templates настроено${NC}"
else
    echo -e "${RED}❌ Монтирование /app/templates не настроено${NC}"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "/app/backend/utils/templates" docker-compose.production.yml; then
    echo -e "${GREEN}✅ Монтирование /app/backend/utils/templates настроено${NC}"
else
    echo -e "${YELLOW}⚠️ Монтирование /app/backend/utils/templates не настроено${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# Проверка зависимостей
echo -e "${YELLOW}📦 Проверка зависимостей...${NC}"

REQUIRED_DEPS=("python-docx" "docxtpl" "python-barcode" "Pillow" "openpyxl")
for dep in "${REQUIRED_DEPS[@]}"; do
    if grep -q "$dep" backend/requirements.txt; then
        echo -e "${GREEN}✅ $dep найден в requirements.txt${NC}"
    else
        echo -e "${RED}❌ $dep не найден в requirements.txt${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""

# Проверка Dockerfile.backend
echo -e "${YELLOW}🐋 Проверка Dockerfile.backend...${NC}"

if grep -q "mkdir -p /app/templates" Dockerfile.backend; then
    echo -e "${GREEN}✅ Создание директории /app/templates настроено${NC}"
else
    echo -e "${RED}❌ Создание директории /app/templates не настроено${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Итоги
echo -e "${BLUE}📊 Итоги проверки:${NC}"
echo -e "Ошибок: ${RED}${ERRORS}${NC}"
echo -e "Предупреждений: ${YELLOW}${WARNINGS}${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ Конфигурация сервера готова к работе!${NC}"
    exit 0
else
    echo -e "${RED}❌ Обнаружены ошибки конфигурации. Исправьте их перед деплоем.${NC}"
    exit 1
fi

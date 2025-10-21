-- Инициализация базы данных для AGB Passports

-- Создаем расширения если нужно
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Создаем пользователя для приложения (если нужно)
-- CREATE USER agb_user WITH PASSWORD 'agb_password';
-- GRANT ALL PRIVILEGES ON DATABASE agb_passports TO agb_user;

-- Устанавливаем права
GRANT ALL PRIVILEGES ON DATABASE agb_passports TO postgres;

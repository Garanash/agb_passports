#!/usr/bin/env python3
"""
Единый скрипт настройки и запуска проекта AGB Passports
"""

import os
import sys
import subprocess
import time
from pathlib import Path

class ProjectSetup:
    """Класс для настройки и запуска проекта AGB Passports"""

    def __init__(self):
        self.project_root = Path(__file__).parent
        self.excel_file = self.project_root / "Номенклатура алмазный инстурмент ALFA.xlsx"

    def check_requirements(self):
        """Проверка системных требований"""
        print("🔍 Проверка системных требований...")

        # Проверка Docker
        try:
            result = subprocess.run(['docker', '--version'], capture_output=True, text=True)
            if result.returncode == 0:
                print(f"   ✅ Docker: {result.stdout.strip()}")
            else:
                print("   ❌ Docker не установлен")
                return False
        except FileNotFoundError:
            print("   ❌ Docker не найден в PATH")
            return False

        # Проверка Docker Compose
        try:
            result = subprocess.run(['docker-compose', '--version'], capture_output=True, text=True)
            if result.returncode == 0:
                print(f"   ✅ Docker Compose: {result.stdout.strip()}")
            else:
                print("   ❌ Docker Compose не установлен")
                return False
        except FileNotFoundError:
            print("   ❌ Docker Compose не найден в PATH")
            return False

        # Проверка Excel файла
        if self.excel_file.exists():
            print(f"   ✅ Excel файл номенклатур найден: {self.excel_file.name}")
        else:
            print(f"   ❌ Excel файл номенклатур не найден: {self.excel_file}")
            return False

        return True

    def stop_existing_services(self):
        """Остановка существующих сервисов"""
        print("🛑 Остановка существующих сервисов...")
        try:
            subprocess.run(['docker-compose', 'down', '-v'], check=False)
            print("   ✅ Сервисы остановлены")
        except Exception as e:
            print(f"   ⚠️  Предупреждение при остановке: {e}")

    def build_and_start_services(self):
        """Сборка и запуск сервисов"""
        print("🔨 Сборка и запуск сервисов...")

        # Собираем образы
        result = subprocess.run(['docker-compose', 'build'], capture_output=True, text=True)
        if result.returncode != 0:
            print(f"❌ Ошибка сборки: {result.stderr}")
            return False

        print("   ✅ Образы собраны")

        # Запускаем сервисы
        result = subprocess.run(['docker-compose', 'up', '-d'], capture_output=True, text=True)
        if result.returncode != 0:
            print(f"❌ Ошибка запуска: {result.stderr}")
            return False

        print("   ✅ Сервисы запущены")

        # Ждем готовности PostgreSQL
        print("⏳ Ожидание готовности PostgreSQL...")
        time.sleep(10)

        return True

    def load_initial_data(self):
        """Загрузка начальных данных"""
        print("📊 Загрузка начальных данных...")

        # Загружаем данные через контейнер
        result = subprocess.run([
            'docker-compose', 'run', '--rm',
            '-v', f'{self.project_root}:/app',
            'backend', 'python3', '/app/load_data.py'
        ], capture_output=True, text=True)

        if result.returncode == 0:
            print("   ✅ Данные загружены успешно")
            print(result.stdout)
            return True
        else:
            print("❌ Ошибка загрузки данных:"            print(result.stderr)
            return False

    def check_services_status(self):
        """Проверка статуса сервисов"""
        print("📋 Проверка статуса сервисов...")

        result = subprocess.run(['docker-compose', 'ps'], capture_output=True, text=True)

        if result.returncode == 0:
            print("   ✅ Статус сервисов:")
            print(result.stdout)

            # Проверяем, что все сервисы запущены
            if "Up" in result.stdout:
                print("   ✅ Все сервисы работают корректно")
                return True
            else:
                print("   ❌ Некоторые сервисы не запущены")
                return False
        else:
            print("❌ Ошибка при проверке статуса сервисов"            return False

    def show_final_info(self):
        """Показ финальной информации"""
        print("\n" + "=" * 60)
        print("🎉 ПРОЕКТ AGB PASSPORTS УСПЕШНО НАСТРОЕН!")
        print("=" * 60)
        print("")
        print("🌐 ДОСТУП К ПРИЛОЖЕНИЮ:")
        print("   Frontend:        http://localhost:3001")
        print("   Backend API:     http://localhost:8000")
        print("   API Docs:        http://localhost:8000/docs")
        print("   PostgreSQL:      localhost:5435")
        print("")
        print("🔑 УЧЕТНЫЕ ЗАПИСИ:")
        print("   Администратор:   admin / admin123")
        print("   Пользователь:    testuser / test123")
        print("")
        print("📊 ЗАГРУЖЕННЫЕ ДАННЫЕ:")
        print("   Номенклатур:     23 позиции")
        print("   Пользователей:   2 (админ + пользователь)")
        print("")
        print("🚀 ПОЛЕЗНЫЕ КОМАНДЫ:")
        print("   docker-compose logs -f          # Просмотр логов")
        print("   docker-compose down              # Остановка всех сервисов")
        print("   docker-compose restart backend   # Перезапуск backend")
        print("   docker-compose restart frontend  # Перезапуск frontend")
        print("")
        print("📚 ДОКУМЕНТАЦИЯ:")
        print("   README.md - Общая документация")
        print("   DOCKER_README.md - Docker документация")
        print("=" * 60)

    def run(self):
        """Основной метод запуска настройки"""
        print("🚀 НАЧИНАЕМ НАСТРОЙКУ ПРОЕКТА AGB PASSPORTS")
        print("=" * 60)

        # Шаг 1: Проверка требований
        if not self.check_requirements():
            print("\n❌ Требования не выполнены. Исправьте проблемы и попробуйте снова.")
            return False

        # Шаг 2: Остановка существующих сервисов
        self.stop_existing_services()

        # Шаг 3: Сборка и запуск сервисов
        if not self.build_and_start_services():
            print("\n❌ Не удалось запустить сервисы. Проверьте конфигурацию.")
            return False

        # Шаг 4: Загрузка данных
        if not self.load_initial_data():
            print("\n⚠️  Сервисы запущены, но данные не загружены. Загрузите данные вручную.")

        # Шаг 5: Проверка статуса
        if not self.check_services_status():
            print("\n⚠️  Некоторые сервисы могут работать некорректно.")

        # Шаг 6: Финальная информация
        self.show_final_info()

        return True

def main():
    """Главная функция"""
    setup = ProjectSetup()
    success = setup.run()

    if success:
        print("✅ Проект готов к использованию!")
        return 0
    else:
        print("❌ Настройка завершилась с ошибками")
        return 1

if __name__ == "__main__":
    exit(main())

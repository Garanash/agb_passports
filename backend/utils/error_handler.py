"""
Централизованная обработка ошибок для стабильности приложения
"""
import sys
import traceback
from typing import Optional, Callable
from functools import wraps


def log_error(error: Exception, context: str = "", print_traceback: bool = True):
    """
    Логирует ошибку с контекстом
    
    Args:
        error: Исключение
        context: Контекст, где произошла ошибка
        print_traceback: Печатать ли полный traceback
    """
    error_msg = f"⚠️ ОШИБКА"
    if context:
        error_msg += f" в {context}"
    error_msg += f": {type(error).__name__}: {str(error)}"
    print(error_msg)
    sys.stdout.flush()
    
    if print_traceback:
        traceback.print_exc()
        sys.stdout.flush()


def safe_execute(func: Callable, *args, context: str = "", default_return=None, **kwargs):
    """
    Безопасное выполнение функции с обработкой ошибок
    
    Args:
        func: Функция для выполнения
        *args: Позиционные аргументы
        context: Контекст выполнения
        default_return: Значение по умолчанию при ошибке
        **kwargs: Именованные аргументы
        
    Returns:
        Результат функции или default_return при ошибке
    """
    try:
        return func(*args, **kwargs)
    except Exception as e:
        log_error(e, context=context)
        return default_return


def error_handler(context: str = "", default_return=None, print_traceback: bool = True):
    """
    Декоратор для обработки ошибок
    
    Args:
        context: Контекст выполнения функции
        default_return: Значение по умолчанию при ошибке
        print_traceback: Печатать ли полный traceback
    """
    def decorator(func: Callable):
        @wraps(func)
        def wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                log_error(e, context=context or func.__name__, print_traceback=print_traceback)
                return default_return
        return wrapper
    return decorator

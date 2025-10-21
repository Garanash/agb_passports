"""
Модели данных для приложения создания паспортов коронок
"""

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Boolean, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import datetime

Base = declarative_base()

class VEDNomenclature(Base):
    """Номенклатура ВЭД"""
    __tablename__ = "ved_nomenclature"

    id = Column(Integer, primary_key=True, index=True)
    code_1c = Column(String, nullable=False, unique=True)
    name = Column(String, nullable=False)
    article = Column(String, nullable=True)
    matrix = Column(String, nullable=True)
    drilling_depth = Column(String, nullable=True)
    height = Column(String, nullable=True)
    thread = Column(String, nullable=True)
    product_type = Column(String, nullable=False, default="коронка")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

class VedPassport(Base):
    """ВЭД паспорта"""
    __tablename__ = "ved_passports"

    id = Column(Integer, primary_key=True, index=True)
    passport_number = Column(String, nullable=False, unique=True)
    title = Column(String, nullable=True)
    description = Column(String, nullable=True)
    status = Column(String, default="active")  # active, archived, draft
    order_number = Column(String, nullable=False)
    quantity = Column(Integer, default=1)
    created_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    nomenclature_id = Column(Integer, ForeignKey("ved_nomenclature.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи
    creator = relationship("User", foreign_keys=[created_by], lazy="selectin")
    nomenclature = relationship("VEDNomenclature", lazy="selectin")

    @staticmethod
    async def generate_passport_number(db: AsyncSession, matrix: str, drilling_depth: str = None, article: str = None, product_type: str = None) -> str:
        """Генерация номера паспорта используя счетчик из БД

        Правила генерации номеров паспортов:
        Коронки: AGB [Глубина бурения] [Матрица] [Серийный номер] [Год]
        Пример: AGB 05-07 NQ 000001 25

        Расширители и башмаки: AGB [Матрица] [Серийный номер] [Год]
        Пример: AGB NQ 000001 25
        """
        current_year = datetime.datetime.now().year
        current_year_suffix = str(current_year)[-2:]  # Последние 2 цифры года
        counter_name = f"ved_passport_{current_year}"

        # Получаем или создаем счетчик для текущего года
        result = await db.execute(
            select(PassportCounter).where(PassportCounter.counter_name == counter_name)
        )
        counter = result.scalar_one_or_none()

        if not counter:
            # Создаем новый счетчик для текущего года
            counter = PassportCounter(
                counter_name=counter_name,
                current_value=0,
                prefix="",
                suffix=current_year_suffix
            )
            db.add(counter)
            await db.flush()
            print(f"DEBUG: Created new counter for year {current_year}")

        # Увеличиваем счетчик
        counter.current_value += 1
        await db.flush()

        # Форматируем серийный номер с ведущими нулями
        serial_number = str(counter.current_value).zfill(6)

        # Формируем номер паспорта согласно правилам
        if product_type == "коронка":
            # Коронки: AGB [Глубина бурения] [Матрица] [Серийный номер] [Год]
            if drilling_depth:
                passport_number = f"AGB {drilling_depth} {matrix} {serial_number} {current_year_suffix}"
            else:
                passport_number = f"AGB {matrix} {serial_number} {current_year_suffix}"
        elif product_type in ["расширитель", "башмак"]:
            # Расширители и башмаки: AGB [Матрица] [Серийный номер] [Год]
            passport_number = f"AGB {matrix} {serial_number} {current_year_suffix}"
        else:
            # Если тип продукта не определен, используем общий формат
            passport_number = f"AGB {matrix} {serial_number} {current_year_suffix}"

        print(f"DEBUG: Generated passport number: {passport_number} (serial: {counter.current_value}, year: {current_year}, type: {product_type})")
        return passport_number

class PassportCounter(Base):
    """Счетчики для ВЭД паспортов"""
    __tablename__ = "passport_counters"

    id = Column(Integer, primary_key=True, index=True)
    counter_name = Column(String, nullable=False, unique=True)
    current_value = Column(Integer, default=0)
    prefix = Column(String, nullable=True)
    suffix = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

class User(Base):
    """Пользователи системы"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, nullable=False, unique=True)
    email = Column(String, nullable=True, unique=True)
    full_name = Column(String, nullable=True)
    hashed_password = Column(String, nullable=False)
    role = Column(String, nullable=False, default="user")  # user, admin
    is_active = Column(Boolean, default=True)
    last_login = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Связи
    created_passports = relationship("VedPassport", foreign_keys="VedPassport.created_by", lazy="selectin")

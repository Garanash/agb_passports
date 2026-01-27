"""
Схемы данных для API паспортов коронок
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class VEDNomenclatureSchema(BaseModel):
    """Схема номенклатуры ВЭД"""
    class Config:
        orm_mode = True
    
    id: int
    code_1c: str
    name: str
    article: Optional[str] = None
    matrix: Optional[str] = None
    drilling_depth: Optional[str] = None
    height: Optional[str] = None
    thread: Optional[str] = None
    product_type: str
    is_active: bool = True
    created_at: datetime
    updated_at: Optional[datetime] = None

class VEDNomenclatureCreate(BaseModel):
    """Схема для создания номенклатуры"""
    code_1c: str = Field(description="Код 1С")
    name: str = Field(description="Наименование")
    article: Optional[str] = None
    matrix: Optional[str] = None
    drilling_depth: Optional[str] = None
    height: Optional[str] = None
    thread: Optional[str] = None
    product_type: str = Field(description="Тип продукта")
    is_active: bool = True

class VEDNomenclatureUpdate(BaseModel):
    """Схема для обновления номенклатуры"""
    code_1c: Optional[str] = None
    name: Optional[str] = None
    article: Optional[str] = None
    matrix: Optional[str] = None
    drilling_depth: Optional[str] = None
    height: Optional[str] = None
    thread: Optional[str] = None
    product_type: Optional[str] = None
    is_active: Optional[bool] = None

class VedPassportSchema(BaseModel):
    """Схема ВЭД паспорта"""
    model_config = ConfigDict(from_attributes=True)

    id: int
    passport_number: str
    title: Optional[str] = None
    description: Optional[str] = None
    status: str = "active"
    order_number: str
    quantity: int = 1
    created_by: Optional[int]
    nomenclature_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    # Связанные объекты
    nomenclature: Optional[VEDNomenclatureSchema] = None
    creator: Optional[dict] = None

class BulkPassportItem(BaseModel):
    """Элемент массового создания паспортов"""
    code_1c: str = Field(description="Код 1С номенклатуры")
    quantity: int = Field(description="Количество", default=1)

class BulkPassportCreate(BaseModel):
    """Схема массового создания ВЭД паспортов"""
    model_config = ConfigDict(from_attributes=True)
    
    order_number: str = Field(description="Номер заказа")
    title: Optional[str] = Field(None, description="Заголовок")
    items: List[BulkPassportItem] = Field(description="Список позиций")

class PassportWithNomenclature(BaseModel):
    """Паспорт с номенклатурой"""
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    passport_number: str
    order_number: str
    quantity: int
    status: str
    created_at: datetime
    nomenclature: VEDNomenclatureSchema

class APIResponse(BaseModel):
    """Стандартный ответ API"""
    success: bool
    message: str
    data: Optional[dict] = None
    errors: Optional[List[str]] = None

class PassportCreateRequest(BaseModel):
    """Запрос на создание паспорта"""
    passport_number: Optional[str] = None
    order_number: str
    title: Optional[str] = None
    description: Optional[str] = None
    quantity: int = 1
    status: str = "active"
    nomenclature_id: int

class MultiplePassportItem(BaseModel):
    """Элемент для множественного создания паспортов"""
    nomenclature_id: int
    order_number: str
    quantity: int = 1

class MultiplePassportCreate(BaseModel):
    """Схема множественного создания паспортов"""
    items: List[MultiplePassportItem]

# Схемы для пользователей
class UserBase(BaseModel):
    """Базовая схема пользователя"""
    username: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    role: str = "user"
    is_active: bool = True

class UserCreate(BaseModel):
    """Схема для создания пользователя"""
    username: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    role: str = "user"
    is_active: bool = True
    password: str

class UserUpdate(BaseModel):
    """Схема для обновления пользователя"""
    username: Optional[str] = None
    email: Optional[str] = None
    full_name: Optional[str] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None
    password: Optional[str] = None

class UserResponse(UserBase):
    """Схема ответа с информацией о пользователе"""
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    last_login: Optional[datetime] = None

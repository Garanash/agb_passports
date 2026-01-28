from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List
from datetime import datetime
from backend.models import VEDNomenclature, User
from backend.database import get_db
from backend.api.schemas import VEDNomenclatureSchema, VEDNomenclatureCreate, VEDNomenclatureUpdate
from backend.api.auth import get_admin_user

router = APIRouter()

@router.get("/", response_model=List[VEDNomenclatureSchema])
def get_nomenclature(db: Session = Depends(get_db)):
    """Получение списка номенклатуры"""
    try:
        # Проверяем подключение к базе данных
        db.execute(text("SELECT 1"))
        
        # Получаем все записи номенклатуры (включая неактивные для админов)
        # Фильтруем только активную номенклатуру для обычных пользователей
        nomenclature = db.query(VEDNomenclature).filter(VEDNomenclature.is_active == True).all()
        print(f"✅ Получено {len(nomenclature)} записей номенклатуры")
        import sys
        sys.stdout.flush()
        return nomenclature
    except Exception as e:
        error_msg = str(e)
        error_type = type(e).__name__
        print(f"❌ Ошибка при получении номенклатуры: {error_type}: {error_msg}")
        import traceback
        traceback.print_exc()
        import sys
        sys.stdout.flush()
        
        # Более информативное сообщение об ошибке
        if "password authentication failed" in error_msg.lower() or "authentication" in error_msg.lower():
            raise HTTPException(status_code=500, detail=f"Ошибка аутентификации в базе данных: {error_msg}")
        elif "connection" in error_msg.lower() or "connect" in error_msg.lower():
            raise HTTPException(status_code=500, detail=f"Ошибка подключения к базе данных: {error_msg}")
        else:
            raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {error_msg}")

@router.get("/{nomenclature_id}", response_model=VEDNomenclatureSchema)
def get_nomenclature_by_id(nomenclature_id: int, db: Session = Depends(get_db)):
    """Получение номенклатуры по ID"""
    try:
        nomenclature = db.query(VEDNomenclature).filter(VEDNomenclature.id == nomenclature_id).first()
        if not nomenclature:
            raise HTTPException(status_code=404, detail="Номенклатура не найдена")
        return nomenclature
    except HTTPException:
        raise
    except Exception as e:
        print(f"Ошибка при получении номенклатуры: {e}")
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

@router.post("/", response_model=VEDNomenclatureSchema)
def create_nomenclature(
    nomenclature_data: VEDNomenclatureCreate,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db)
):
    """Создание новой номенклатуры (только для администраторов)"""
    try:
        # Проверяем, не существует ли уже номенклатура с таким кодом 1С
        existing = db.query(VEDNomenclature).filter(VEDNomenclature.code_1c == nomenclature_data.code_1c).first()
        if existing:
            raise HTTPException(status_code=400, detail="Номенклатура с таким кодом 1С уже существует")
        
        # Создаем новую номенклатуру
        new_nomenclature = VEDNomenclature(
            code_1c=nomenclature_data.code_1c,
            name=nomenclature_data.name,
            article=nomenclature_data.article,
            matrix=nomenclature_data.matrix,
            drilling_depth=nomenclature_data.drilling_depth,
            height=nomenclature_data.height,
            thread=nomenclature_data.thread,
            product_type=nomenclature_data.product_type,
            is_active=nomenclature_data.is_active,
            created_at=datetime.now(),
            updated_at=datetime.now()
        )
        
        db.add(new_nomenclature)
        db.commit()
        db.refresh(new_nomenclature)
        
        return new_nomenclature
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"Ошибка при создании номенклатуры: {e}")
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

@router.put("/{nomenclature_id}", response_model=VEDNomenclatureSchema)
def update_nomenclature(
    nomenclature_id: int,
    nomenclature_data: VEDNomenclatureUpdate,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db)
):
    """Обновление номенклатуры (только для администраторов)"""
    try:
        nomenclature = db.query(VEDNomenclature).filter(VEDNomenclature.id == nomenclature_id).first()
        if not nomenclature:
            raise HTTPException(status_code=404, detail="Номенклатура не найдена")
        
        # Обновляем поля
        if hasattr(nomenclature_data, 'model_dump'):
            update_data = nomenclature_data.model_dump(exclude_unset=True)
        else:
            update_data = nomenclature_data.dict(exclude_unset=True)

        # Защита от изменения первичного ключа
        update_data.pop("id", None)

        # Если меняем code_1c — проверяем уникальность
        new_code_1c = update_data.get("code_1c")
        if new_code_1c and new_code_1c != nomenclature.code_1c:
            existing = (
                db.query(VEDNomenclature)
                .filter(
                    VEDNomenclature.code_1c == new_code_1c,
                    VEDNomenclature.id != nomenclature_id,
                )
                .first()
            )
            if existing:
                raise HTTPException(
                    status_code=400,
                    detail="Номенклатура с таким кодом 1С уже существует",
                )

        for field, value in update_data.items():
            # Не даём превратить обязательные поля в NULL
            if field == "product_type" and (value is None or str(value).strip() == ""):
                continue
            if not hasattr(nomenclature, field):
                continue
            setattr(nomenclature, field, value)
        
        nomenclature.updated_at = datetime.now()
        
        db.commit()
        db.refresh(nomenclature)
        
        return nomenclature
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"Ошибка при обновлении номенклатуры: {e}")
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

@router.delete("/{nomenclature_id}")
def delete_nomenclature(
    nomenclature_id: int,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db)
):
    """Удаление номенклатуры (только для администраторов)"""
    try:
        nomenclature = db.query(VEDNomenclature).filter(VEDNomenclature.id == nomenclature_id).first()
        if not nomenclature:
            raise HTTPException(status_code=404, detail="Номенклатура не найдена")
        
        # Проверяем, нет ли связанных паспортов
        from backend.models import VedPassport
        passports_count = db.query(VedPassport).filter(VedPassport.nomenclature_id == nomenclature_id).count()
        if passports_count > 0:
            # Вместо удаления делаем неактивной
            nomenclature.is_active = False
            nomenclature.updated_at = datetime.now()
            db.commit()
            return {"message": "Номенклатура деактивирована (есть связанные паспорта)", "deactivated": True}
        
        db.delete(nomenclature)
        db.commit()
        
        return {"message": "Номенклатура успешно удалена"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"Ошибка при удалении номенклатуры: {e}")
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

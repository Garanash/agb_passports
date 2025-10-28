from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
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
        nomenclature = db.query(VEDNomenclature).all()
        return nomenclature
    except Exception as e:
        print(f"Ошибка при получении номенклатуры: {e}")
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

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
        update_data = nomenclature_data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
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

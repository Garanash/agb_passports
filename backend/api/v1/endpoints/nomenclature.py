from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from backend.models import VEDNomenclature
from backend.database import get_db
from backend.api.schemas import VEDNomenclatureSchema

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

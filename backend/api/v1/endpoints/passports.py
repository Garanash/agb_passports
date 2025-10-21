"""
API эндпоинты для создания паспортов коронок
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Dict, Optional
import io
from datetime import datetime

from backend.models import User, VEDNomenclature, VedPassport, PassportCounter
from backend.api.schemas import (
    VEDNomenclatureSchema,
    VedPassportSchema,
    BulkPassportCreate,
    PassportWithNomenclature,
    APIResponse,
    PassportCreateRequest,
    MultiplePassportCreate,
    MultiplePassportItem
)
from backend.api.auth import get_current_user, get_current_active_user, get_admin_user
from backend.utils.pdf_generator import generate_bulk_passports_pdf
from backend.database import get_db, get_async_db

router = APIRouter()

@router.get("/{passport_id:path}", response_model=VedPassportSchema)
def get_ved_passport(
    passport_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Получение конкретного паспорта ВЭД по ID"""
    try:
        # Проверяем, является ли passport_id числом
        if not passport_id.isdigit():
            raise HTTPException(status_code=404, detail="Паспорт не найден")

        passport_id_int = int(passport_id)
        passport = db.query(VedPassport).filter(VedPassport.id == passport_id_int).first()

        if not passport:
            raise HTTPException(status_code=404, detail="Паспорт не найден")

        if passport.created_by != current_user.id and current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Доступ запрещен")

        return passport

    except HTTPException:
        raise
    except Exception as e:
        print(f"Ошибка при получении паспорта: {e}")
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

@router.get("/nomenclature/", response_model=List[VEDNomenclatureSchema])
def get_ved_nomenclature(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Получение списка номенклатуры для паспортов ВЭД"""
    try:
        nomenclature = db.query(VEDNomenclature).filter(VEDNomenclature.is_active == True).all()
        return nomenclature
    except Exception as e:
        print(f"Ошибка при получении номенклатуры: {e}")
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

@router.get("/archive/filters", response_model=Dict[str, List[str]])
def get_archive_filters(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Получение доступных фильтров для архива"""
    try:
        # Получаем уникальные типы продуктов
        product_types = db.query(VEDNomenclature.product_type).filter(
            VEDNomenclature.product_type.isnot(None),
            VEDNomenclature.is_active == True
        ).distinct().all()
        
        # Получаем уникальные матрицы
        matrices = db.query(VEDNomenclature.matrix).filter(
            VEDNomenclature.matrix.isnot(None),
            VEDNomenclature.is_active == True
        ).distinct().all()
        
        # Получаем уникальные статусы паспортов
        statuses = db.query(VedPassport.status).filter(
            VedPassport.status.isnot(None)
        ).distinct().all()
        
        return {
            "product_types": [item[0] for item in product_types if item[0]],
            "matrices": [item[0] for item in matrices if item[0]],
            "statuses": [item[0] for item in statuses if item[0]]
        }
        
    except Exception as e:
        print(f"Ошибка при получении фильтров: {e}")
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

@router.get("/")
def get_ved_passports(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Получение списка паспортов ВЭД"""
    try:
        # Админы видят все активные паспорта, пользователи - только свои
        if current_user.role == "admin":
            passports = db.query(VedPassport).filter(VedPassport.status == "active").limit(10).all()
        else:
            passports = db.query(VedPassport).filter(
                VedPassport.status == "active",
                VedPassport.created_by == current_user.id
            ).limit(10).all()

        # Возвращаем простые данные без обработки
        result = []
        for passport in passports:
            try:
                result.append({
                    "id": passport.id,
                    "passport_number": passport.passport_number,
                    "status": passport.status,
                    "created_by": passport.created_by,
                    "order_number": passport.order_number,
                    "nomenclature_id": passport.nomenclature_id,
                    "created_at": str(passport.created_at) if passport.created_at else None
                })
            except Exception as e:
                print(f"Ошибка обработки паспорта {passport.id}: {e}")
                continue

        return result

    except Exception as e:
        print(f"Ошибка при получении паспортов: {e}")
        import traceback
        traceback.print_exc()
        return {"error": str(e)}

@router.get("/test-database")
def simple_test(db: Session = Depends(get_db)):
    """Простой тест с доступом к БД"""
    try:
        # Получаем количество паспортов
        count = db.query(VedPassport).count()
        return {"message": "API работает", "passports_count": count, "data": [1, 2, 3]}
    except Exception as e:
        return {"error": str(e)}

@router.get("/passports-list")
def get_passports_list(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Получение списка паспортов ВЭД (альтернативный эндпоинт)"""
    try:
        # Админы видят все активные паспорта, пользователи - только свои
        if current_user.role == "admin":
            passports = db.query(VedPassport).filter(VedPassport.status == "active").limit(10).all()
        else:
            passports = db.query(VedPassport).filter(
                VedPassport.status == "active",
                VedPassport.created_by == current_user.id
            ).limit(10).all()

        # Возвращаем простые данные без обработки
        result = []
        for passport in passports:
            try:
                result.append({
                    "id": passport.id,
                    "passport_number": passport.passport_number,
                    "status": passport.status,
                    "created_by": passport.created_by,
                    "order_number": passport.order_number,
                    "nomenclature_id": passport.nomenclature_id,
                    "created_at": str(passport.created_at) if passport.created_at else None
                })
            except Exception as e:
                print(f"Ошибка обработки паспорта {passport.id}: {e}")
                continue

        return result

    except Exception as e:
        print(f"Ошибка при получении паспортов: {e}")
        import traceback
        traceback.print_exc()
        return {"error": str(e)}

@router.get("/debug")
def test_passports(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Простой тест получения паспортов"""
    try:
        # Получаем первые 5 паспортов для теста
        passports = db.query(VedPassport).limit(5).all()

        # Возвращаем простые данные без обработки
        return [
            {
                "id": p.id,
                "passport_number": p.passport_number,
                "status": p.status,
                "created_by": p.created_by,
                "order_number": p.order_number
            }
            for p in passports
        ]

    except Exception as e:
        print(f"Ошибка при получении паспортов: {e}")
        return {"error": str(e)}

@router.get("/archive/", response_model=List[VedPassportSchema])
def get_user_archive(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Архив паспортов"""
    try:
        # Админы видят все архивированные паспорта, пользователи - только свои
        if current_user.role == "admin":
            passports = db.query(VedPassport).filter(
                VedPassport.status == "archived"
            ).order_by(VedPassport.created_at.desc()).all()
        else:
            passports = db.query(VedPassport).filter(
                VedPassport.created_by == current_user.id,
                VedPassport.status == "archived"
            ).order_by(VedPassport.created_at.desc()).all()

        # Создаем объекты для ответа с загруженными связанными данными
        result_passports = []
        for passport in passports:
            # Загружаем создателя паспорта
            creator = db.query(User).filter(User.id == passport.created_by).first()
            # Загружаем номенклатуру
            nomenclature = db.query(VEDNomenclature).filter(VEDNomenclature.id == passport.nomenclature_id).first()

            # Создаем объект для ответа
            passport_data = {
                "id": passport.id,
                "passport_number": passport.passport_number,
                "title": passport.title,
                "description": passport.description,
                "status": passport.status,
                "order_number": passport.order_number,
                "quantity": passport.quantity,
                "created_by": passport.created_by,
                "nomenclature_id": passport.nomenclature_id,
                "created_at": passport.created_at,
                "updated_at": passport.updated_at,
                "creator": {
                    "id": creator.id if creator else None,
                    "username": creator.username if creator else None,
                    "email": creator.email if creator else None,
                    "full_name": creator.full_name if creator else None,
                    "role": creator.role if creator else None
                } if creator else None,
                "nomenclature": nomenclature
            }
            result_passports.append(passport_data)

        return result_passports
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

@router.post("/", response_model=APIResponse)
async def create_single_passport(
    passport_data: PassportCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Создание одного паспорта ВЭД"""
    try:
        # Получаем номенклатуру
        nomenclature = await db.get(VEDNomenclature, passport_data.nomenclature_id)
        if not nomenclature:
            raise HTTPException(status_code=404, detail="Номенклатура не найдена")
        
        created_passports = []
        
        for i in range(passport_data.quantity):
            # Генерируем номер паспорта
            if passport_data.passport_number:
                passport_number = passport_data.passport_number
                if passport_data.quantity > 1:
                    passport_number = f"{passport_data.passport_number}-{i+1:03d}"
            else:
                passport_number = await VedPassport.generate_passport_number(
                    db=db,
                    matrix=nomenclature.matrix or "NQ",
                    drilling_depth=nomenclature.drilling_depth,
                    article=nomenclature.article,
                    product_type=nomenclature.product_type
                )
            
            # Создаем паспорт
            passport = VedPassport(
                passport_number=passport_number,
                order_number=passport_data.order_number,
                title=passport_data.title or f"Паспорт ВЭД {nomenclature.name}",
                description=passport_data.description or f"Паспорт для номенклатуры {nomenclature.name}",
                quantity=1,
                status=passport_data.status,
                created_by=current_user.id,
                nomenclature_id=passport_data.nomenclature_id
            )
            
            db.add(passport)
            await db.flush()
            
            created_passports.append({
                "passport_id": passport.id,
                "passport_number": passport.passport_number
            })
        
        await db.commit()
        
        return APIResponse(
            success=True,
            message=f"Создано паспортов: {len(created_passports)}",
            data={"created": created_passports}
        )
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка создания паспорта: {str(e)}")

@router.post("/multiple", response_model=List[dict])
async def create_multiple_passports(
    multiple_data: MultiplePassportCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Создание множественных паспортов ВЭД"""
    try:
        created_passports = []
        
        for item in multiple_data.items:
            # Получаем номенклатуру
            nomenclature = await db.get(VEDNomenclature, item.nomenclature_id)
            if not nomenclature:
                raise HTTPException(status_code=404, detail=f"Номенклатура с ID {item.nomenclature_id} не найдена")
            
            # Создаем паспорта для каждого количества
            for i in range(item.quantity):
                # Генерируем номер паспорта
                passport_number = await VedPassport.generate_passport_number(
                    db=db,
                    matrix=nomenclature.matrix or "NQ",
                    drilling_depth=nomenclature.drilling_depth,
                    article=nomenclature.article,
                    product_type=nomenclature.product_type
                )
                
                # Создаем паспорт
                passport = VedPassport(
                    passport_number=passport_number,
                    order_number=item.order_number,
                    title=f"Паспорт ВЭД {nomenclature.name}",
                    description=f"Паспорт для номенклатуры {nomenclature.name}",
                    quantity=1,
                    status="active",
                    created_by=current_user.id,
                    nomenclature_id=item.nomenclature_id
                )
                
                db.add(passport)
                await db.flush()
                
                created_passports.append({
                    "id": passport.id,
                    "passport_number": passport.passport_number,
                    "nomenclature_name": nomenclature.name,
                    "order_number": item.order_number,
                    "created_at": passport.created_at.isoformat()
                })
        
        await db.commit()
        
        return created_passports
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка создания паспортов: {str(e)}")

@router.post("/bulk/", response_model=APIResponse)
async def create_bulk_passports(
    bulk_data: BulkPassportCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Массовое создание паспортов ВЭД"""
    try:
        created_passports = []
        errors = []
        
        for item in bulk_data.items:
            try:
                # Находим номенклатуру по коду 1С
                nomenclature = db.query(VEDNomenclature).filter(
                    VEDNomenclature.code_1c == item.code_1c,
                    VEDNomenclature.is_active == True
                ).first()
                
                if not nomenclature:
                    errors.append(f"Номенклатура с кодом {item.code_1c} не найдена")
                    continue
                
                # Создаем паспорты для каждого экземпляра
                for i in range(item.quantity):
                    passport_number = await VedPassport.generate_passport_number(
                        db=db,
                        matrix=nomenclature.matrix or "NQ",
                        drilling_depth=nomenclature.drilling_depth,
                        article=nomenclature.article,
                        product_type=nomenclature.product_type
                    )
                    
                    passport = VedPassport(
                        passport_number=passport_number,
                        order_number=bulk_data.order_number,
                        title=bulk_data.title or f"Паспорт ВЭД {nomenclature.name}",
                        description=f"Массовое создание паспортов ВЭД",
                        quantity=1,
                        status="active",
                        created_by=current_user.id,
                        nomenclature_id=nomenclature.id
                    )
                    
                    db.add(passport)
                    await db.flush()
                    
                    created_passports.append({
                        "id": passport.id,
                        "passport_number": passport.passport_number,
                        "order_number": passport.order_number,
                        "nomenclature": nomenclature,
                        "quantity": 1,
                        "status": passport.status,
                        "created_at": passport.created_at.isoformat()
                    })
                    
            except Exception as e:
                errors.append(f"Ошибка при создании паспорта для {item.code_1c}: {str(e)}")
        
        await db.commit()
        
        return APIResponse(
            success=True,
            message=f"Создано паспортов: {len(created_passports)}",
            data={
                "passports": created_passports,
                "errors": errors
            }
        )
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка массового создания паспортов: {str(e)}")

@router.post("/export/bulk/pdf")
async def export_bulk_pdf(
    passport_ids: List[int],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Экспорт выбранных паспортов в один PDF"""
    if not passport_ids:
        raise HTTPException(status_code=400, detail="Список паспортов пуст")
    try:
        from sqlalchemy import select
        passports_query = select(VedPassport).where(VedPassport.id.in_(passport_ids))
        result = await db.execute(passports_query)
        passports = result.scalars().all()
        
        if not passports:
            raise HTTPException(status_code=404, detail="Паспорта не найдены")
        
        # Проверяем права доступа
        accessible_passports = []
        for passport in passports:
            if passport.created_by == current_user.id or current_user.role == "admin":
                accessible_passports.append(passport)
        
        if not accessible_passports:
            raise HTTPException(status_code=403, detail="Нет доступа к указанным паспортам")
        
        pdf_bytes = generate_bulk_passports_pdf(accessible_passports)
        return StreamingResponse(io.BytesIO(pdf_bytes), media_type="application/pdf", headers={
            "Content-Disposition": "attachment; filename=ved_passports.pdf"
        })
    except HTTPException:
        raise
    except Exception as e:
        print(f"Ошибка при экспорте PDF: {e}")
        raise HTTPException(status_code=500, detail=f"Ошибка экспорта PDF: {str(e)}")

@router.post("/export/created/pdf", response_class=StreamingResponse)
async def export_passports_pdf(
    passport_ids: List[int],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Экспорт паспортов в PDF"""
    try:
        # Получаем паспорта по ID
        passports = []
        for passport_id in passport_ids:
            passport = await db.get(VedPassport, passport_id)
            if passport:
                # Проверяем права доступа
                if passport.created_by != current_user.id and current_user.role != "admin":
                    continue
                passports.append(passport)
        
        if not passports:
            raise HTTPException(status_code=404, detail="Паспорта не найдены или нет доступа")
        
        # Генерируем PDF
        pdf_content = generate_bulk_passports_pdf(passports)
        
        # Создаем поток для ответа
        pdf_stream = io.BytesIO(pdf_content)
        
        return StreamingResponse(
            io.BytesIO(pdf_content),
            media_type="application/pdf",
            headers={"Content-Disposition": "attachment; filename=passports.pdf"}
        )
        
    except Exception as e:
        print(f"Ошибка при экспорте PDF: {e}")
        raise HTTPException(status_code=500, detail=f"Ошибка экспорта PDF: {str(e)}")


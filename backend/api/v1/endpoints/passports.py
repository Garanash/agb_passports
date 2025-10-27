"""
API эндпоинты для создания паспортов коронок
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Dict, Optional
import io
import pandas as pd
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

@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    """Проверка здоровья API"""
    try:
        count = db.query(VedPassport).count()
        return {"status": "healthy", "service": "passports", "version": "1.0.0", "passports_count": count}
    except Exception as e:
        return {"status": "error", "error": str(e)}

@router.get("/test")
def test_endpoint():
    """Тестовый эндпоинт"""
    return {"message": "Test endpoint works"}

@router.get("/debug-passports")
def debug_passports(db: Session = Depends(get_db)):
    """Отладочный эндпоинт для паспортов"""
    try:
        passports = db.query(VedPassport).limit(5).all()
        result = []
        for passport in passports:
            result.append({
                "id": passport.id,
                "passport_number": passport.passport_number,
                "status": passport.status,
                "created_by": passport.created_by,
                "order_number": passport.order_number,
                "nomenclature_id": passport.nomenclature_id
            })
        return {"passports": result, "count": len(result)}
    except Exception as e:
        return {"error": str(e)}

@router.get("/public-passports")
def public_passports(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Получение всех паспортов для архива"""
    try:
        # Админы видят все паспорта, пользователи - только свои
        if current_user.role == "admin":
            passports = db.query(VedPassport).order_by(VedPassport.created_at.desc()).all()
        else:
            passports = db.query(VedPassport).filter(
                VedPassport.created_by == current_user.id
            ).order_by(VedPassport.created_at.desc()).all()

        print(f"[public-passports] Получено {len(passports)} паспортов для пользователя {current_user.id} (роль: {current_user.role})")

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
                "created_at": passport.created_at.isoformat() if passport.created_at else None,
                "updated_at": passport.updated_at.isoformat() if passport.updated_at else None,
                "creator": {
                    "id": creator.id if creator else None,
                    "username": creator.username if creator else None,
                    "email": creator.email if creator else None,
                    "full_name": creator.full_name if creator else None,
                    "role": creator.role if creator else None
                } if creator else None,
                "nomenclature": {
                    "id": nomenclature.id if nomenclature else None,
                    "code_1c": nomenclature.code_1c if nomenclature else None,
                    "name": nomenclature.name if nomenclature else None,
                    "article": nomenclature.article if nomenclature else None,
                    "matrix": nomenclature.matrix if nomenclature else None,
                    "drilling_depth": nomenclature.drilling_depth if nomenclature else None,
                    "height": nomenclature.height if nomenclature else None,
                    "thread": nomenclature.thread if nomenclature else None,
                    "product_type": nomenclature.product_type if nomenclature else None,
                    "is_active": nomenclature.is_active if nomenclature else None,
                    "created_at": nomenclature.created_at.isoformat() if nomenclature and nomenclature.created_at else None,
                    "updated_at": nomenclature.updated_at.isoformat() if nomenclature and nomenclature.updated_at else None
                } if nomenclature else None
            }
            result_passports.append(passport_data)

        return result_passports
    except Exception as e:
        print(f"Ошибка при получении паспортов: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

@router.get("/get-all-passports")
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

@router.post("/{passport_id}/archive")
async def archive_passport(
    passport_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Архивирование паспорта"""
    try:
        passport = await db.get(VedPassport, passport_id)
        if not passport:
            raise HTTPException(status_code=404, detail="Паспорт не найден")
        
        # Проверяем права доступа
        if passport.created_by != current_user.id and current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Нет доступа к этому паспорту")
        
        # Изменяем статус на архивированный
        passport.status = "archived"
        await db.commit()
        
        return {"message": "Паспорт успешно архивирован", "passport_id": passport_id}
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка архивирования паспорта: {str(e)}")

@router.post("/{passport_id}/activate")
async def activate_passport(
    passport_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Активация паспорта"""
    try:
        passport = await db.get(VedPassport, passport_id)
        if not passport:
            raise HTTPException(status_code=404, detail="Паспорт не найден")
        
        # Проверяем права доступа
        if passport.created_by != current_user.id and current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Нет доступа к этому паспорту")
        
        # Изменяем статус на активный
        passport.status = "active"
        await db.commit()
        
        return {"message": "Паспорт успешно активирован", "passport_id": passport_id}
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка активации паспорта: {str(e)}")

# Временно отключаем роут для получения конкретного паспорта
# @router.get("/passport/{passport_id}", response_model=VedPassportSchema)
# def get_ved_passport(
#     passport_id: int,
#     current_user: User = Depends(get_current_user),
#     db: Session = Depends(get_db)
# ):
#     """Получение конкретного паспорта ВЭД по ID"""
#     try:
#         passport = db.query(VedPassport).filter(VedPassport.id == passport_id).first()

#         if not passport:
#             raise HTTPException(status_code=404, detail="Паспорт не найден")

#         if passport.created_by != current_user.id and current_user.role != "admin":
#             raise HTTPException(status_code=403, detail="Доступ запрещен")

#         return passport

#     except HTTPException:
#         raise
#     except Exception as e:
#         print(f"Ошибка при получении паспорта: {e}")
#         raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

@router.get("/export/excel")
def export_passports_excel(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Экспорт всех паспортов в Excel"""
    try:
        # Получаем все паспорта в зависимости от роли пользователя
        if current_user.role == "admin":
            passports = db.query(VedPassport).order_by(VedPassport.created_at.desc()).all()
        else:
            passports = db.query(VedPassport).filter(
                VedPassport.created_by == current_user.id
            ).order_by(VedPassport.created_at.desc()).all()
        
        if not passports:
            raise HTTPException(status_code=404, detail="Паспорта не найдены")
        
        # Подготавливаем данные для Excel
        data = []
        for passport in passports:
            # Загружаем связанные данные
            creator = db.query(User).filter(User.id == passport.created_by).first()
            nomenclature = db.query(VEDNomenclature).filter(VEDNomenclature.id == passport.nomenclature_id).first()
            
            data.append({
                'ID паспорта': passport.id,
                'Номер паспорта': passport.passport_number,
                'Название': passport.title or '',
                'Описание': passport.description or '',
                'Статус': passport.status or '',
                'Номер заказа': passport.order_number or '',
                'Количество': passport.quantity or 1,
                'Создатель': creator.full_name if creator and creator.full_name else creator.username if creator else '',
                'Email создателя': creator.email if creator else '',
                'Код 1С': nomenclature.code_1c if nomenclature else '',
                'Артикул': nomenclature.article if nomenclature else '',
                'Наименование': nomenclature.name if nomenclature else '',
                'Матрица': nomenclature.matrix if nomenclature else '',
                'Глубина бурения': nomenclature.drilling_depth if nomenclature else '',
                'Высота': nomenclature.height if nomenclature else '',
                'Резьба': nomenclature.thread if nomenclature else '',
                'Тип продукта': nomenclature.product_type if nomenclature else '',
                'Дата создания': passport.created_at.strftime('%d.%m.%Y %H:%M') if passport.created_at else '',
                'Дата обновления': passport.updated_at.strftime('%d.%m.%Y %H:%M') if passport.updated_at else ''
            })
        
        # Создаем DataFrame
        df = pd.DataFrame(data)
        
        # Создаем Excel файл в памяти
        output = io.BytesIO()
        with pd.ExcelWriter(output, engine='openpyxl') as writer:
            df.to_excel(writer, sheet_name='Паспорта ВЭД', index=False)
            
            # Получаем рабочую книгу для форматирования
            workbook = writer.book
            worksheet = writer.sheets['Паспорта ВЭД']
            
            # Автоподбор ширины колонок
            for column in worksheet.columns:
                max_length = 0
                column_letter = column[0].column_letter
                for cell in column:
                    try:
                        if len(str(cell.value)) > max_length:
                            max_length = len(str(cell.value))
                    except:
                        pass
                adjusted_width = min(max_length + 2, 50)  # Максимальная ширина 50
                worksheet.column_dimensions[column_letter].width = adjusted_width
        
        output.seek(0)
        
        # Генерируем имя файла с датой
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"ved_passports_export_{timestamp}.xlsx"
        
        return StreamingResponse(
            io.BytesIO(output.read()),
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
        
    except Exception as e:
        print(f"Ошибка при экспорте Excel: {e}")
        raise HTTPException(status_code=500, detail=f"Ошибка экспорта Excel: {str(e)}")

@router.post("/export/excel/selected")
def export_selected_passports_excel(
    passport_ids: List[int],
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Экспорт выбранных паспортов в Excel"""
    try:
        if not passport_ids:
            raise HTTPException(status_code=400, detail="Не выбраны паспорта для экспорта")
        
        # Получаем выбранные паспорта в зависимости от роли пользователя
        if current_user.role == "admin":
            passports = db.query(VedPassport).filter(
                VedPassport.id.in_(passport_ids)
            ).order_by(VedPassport.created_at.desc()).all()
        else:
            passports = db.query(VedPassport).filter(
                VedPassport.id.in_(passport_ids),
                VedPassport.created_by == current_user.id
            ).order_by(VedPassport.created_at.desc()).all()
        
        if not passports:
            raise HTTPException(status_code=404, detail="Выбранные паспорта не найдены")
        
        # Подготавливаем данные для Excel
        data = []
        for passport in passports:
            # Загружаем связанные данные
            creator = db.query(User).filter(User.id == passport.created_by).first()
            nomenclature = db.query(VEDNomenclature).filter(VEDNomenclature.id == passport.nomenclature_id).first()
            
            data.append({
                'ID паспорта': passport.id,
                'Номер паспорта': passport.passport_number,
                'Название': passport.title or '',
                'Описание': passport.description or '',
                'Статус': passport.status or '',
                'Номер заказа': passport.order_number or '',
                'Количество': passport.quantity or 1,
                'Создатель': creator.full_name if creator and creator.full_name else creator.username if creator else '',
                'Email создателя': creator.email if creator else '',
                'Код 1С': nomenclature.code_1c if nomenclature else '',
                'Артикул': nomenclature.article if nomenclature else '',
                'Наименование': nomenclature.name if nomenclature else '',
                'Матрица': nomenclature.matrix if nomenclature else '',
                'Глубина бурения': nomenclature.drilling_depth if nomenclature else '',
                'Высота': nomenclature.height if nomenclature else '',
                'Резьба': nomenclature.thread if nomenclature else '',
                'Тип продукта': nomenclature.product_type if nomenclature else '',
                'Дата создания': passport.created_at.strftime('%d.%m.%Y %H:%M') if passport.created_at else '',
                'Дата обновления': passport.updated_at.strftime('%d.%m.%Y %H:%M') if passport.updated_at else ''
            })
        
        # Создаем DataFrame
        df = pd.DataFrame(data)
        
        # Создаем Excel файл в памяти
        output = io.BytesIO()
        with pd.ExcelWriter(output, engine='openpyxl') as writer:
            df.to_excel(writer, sheet_name='Выбранные паспорта ВЭД', index=False)
            
            # Получаем рабочую книгу для форматирования
            workbook = writer.book
            worksheet = writer.sheets['Выбранные паспорта ВЭД']
            
            # Автоподбор ширины колонок
            for column in worksheet.columns:
                max_length = 0
                column_letter = column[0].column_letter
                for cell in column:
                    try:
                        if len(str(cell.value)) > max_length:
                            max_length = len(str(cell.value))
                    except:
                        pass
                adjusted_width = min(max_length + 2, 50)  # Максимальная ширина 50
                worksheet.column_dimensions[column_letter].width = adjusted_width
        
        output.seek(0)
        
        # Генерируем имя файла с датой
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"ved_passports_selected_{timestamp}.xlsx"
        
        return StreamingResponse(
            io.BytesIO(output.read()),
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
        
    except Exception as e:
        print(f"Ошибка при экспорте выбранных паспортов в Excel: {e}")
        raise HTTPException(status_code=500, detail=f"Ошибка экспорта выбранных паспортов в Excel: {str(e)}")


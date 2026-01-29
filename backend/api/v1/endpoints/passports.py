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
from backend.utils.pdf_generator import generate_bulk_passports_pdf, generate_stickers_pdf_reportlab
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
    page: int = 1,
    page_size: int = 20,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Получение списка паспортов ВЭД с пагинацией"""
    try:
        # Админы видят все активные паспорта, пользователи - только свои (любого статуса)
        if current_user.role == "admin":
            query = db.query(VedPassport).filter(
                (VedPassport.status == "active") | (VedPassport.status.is_(None))
            ).order_by(VedPassport.created_at.desc())
            total_count = query.count()
        else:
            query = db.query(VedPassport).filter(
                VedPassport.created_by == current_user.id
            ).filter(
                (VedPassport.status == "active") | (VedPassport.status.is_(None))
            ).order_by(VedPassport.created_at.desc())
            total_count = query.count()

        # Применяем пагинацию
        skip = (page - 1) * page_size
        passports = query.offset(skip).limit(page_size).all()

        # Создаем объекты для ответа с загруженными связанными данными
        result_passports = []
        for passport in passports:
            try:
                # Загружаем создателя паспорта
                creator = db.query(User).filter(User.id == passport.created_by).first()
                # Загружаем номенклатуру
                nomenclature = db.query(VEDNomenclature).filter(VEDNomenclature.id == passport.nomenclature_id).first()

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
                    } if nomenclature else None
                }
                result_passports.append(passport_data)
            except Exception as e:
                print(f"Ошибка обработки паспорта {passport.id}: {e}")
                import traceback
                traceback.print_exc()
                continue

        return {
            "passports": result_passports,
            "pagination": {
                "current_page": page,
                "page_size": page_size,
                "total_count": total_count,
                "total_pages": (total_count + page_size - 1) // page_size if total_count > 0 else 0
            }
        }

    except Exception as e:
        print(f"Ошибка при получении паспортов: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

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

@router.get("/orders-summary", response_model=Dict)
def get_orders_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Список заказов с количеством паспортов для ленивой загрузки архива"""
    try:
        from sqlalchemy import func
        if current_user.role == "admin":
            q = db.query(VedPassport.order_number, func.count(VedPassport.id).label("count")).group_by(VedPassport.order_number).order_by(VedPassport.order_number)
        else:
            q = db.query(VedPassport.order_number, func.count(VedPassport.id).label("count")).filter(
                VedPassport.created_by == current_user.id
            ).group_by(VedPassport.order_number).order_by(VedPassport.order_number)
        rows = q.all()
        orders = [{"order_number": (r.order_number or "Без заказа"), "count": r.count} for r in rows]
        return {"orders": orders}
    except Exception as e:
        print(f"Ошибка при получении списка заказов: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/public-passports")
def public_passports(
    page: int = 1,
    page_size: int = 20,
    order_number: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Получение всех паспортов для архива с пагинацией (опционально по номеру заказа)"""
    try:
        # Админы видят все паспорта, пользователи - только свои (включая все статусы)
        if current_user.role == "admin":
            query = db.query(VedPassport).order_by(VedPassport.created_at.desc())
        else:
            query = db.query(VedPassport).filter(
                VedPassport.created_by == current_user.id
            ).order_by(VedPassport.created_at.desc())

        if order_number is not None and order_number.strip() != "":
            if order_number.strip() == "Без заказа":
                query = query.filter((VedPassport.order_number == None) | (VedPassport.order_number == ""))
            else:
                query = query.filter(VedPassport.order_number == order_number.strip())

        total_count = query.count()
        # Применяем пагинацию
        skip = (page - 1) * page_size
        passports = query.offset(skip).limit(page_size).all()

        print(f"[public-passports] Получено {len(passports)} паспортов для пользователя {current_user.id} (роль: {current_user.role}), страница {page}, всего: {total_count}")

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

        return {
            "passports": result_passports,
            "pagination": {
                "current_page": page,
                "page_size": page_size,
                "total_count": total_count,
                "total_pages": (total_count + page_size - 1) // page_size
            }
        }
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
        from sqlalchemy.orm import joinedload
        
        # Админы видят все архивированные паспорта, пользователи - только свои
        query = db.query(VedPassport).options(
            joinedload(VedPassport.nomenclature)
        )
        
        if current_user.role == "admin":
            passports = query.filter(
                VedPassport.status == "archived"
            ).order_by(VedPassport.created_at.desc()).all()
        else:
            passports = query.filter(
                VedPassport.created_by == current_user.id,
                VedPassport.status == "archived"
            ).order_by(VedPassport.created_at.desc()).all()

        print(f"[archive] Получено {len(passports)} архивированных паспортов для пользователя {current_user.id} (роль: {current_user.role})")

        # Создаем объекты для ответа с загруженными связанными данными
        result_passports = []
        for passport in passports:
            # Загружаем создателя паспорта
            creator = db.query(User).filter(User.id == passport.created_by).first()

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
                "nomenclature": passport.nomenclature  # Используем загруженную через joinedload
            }
            result_passports.append(passport_data)

        return result_passports
    except Exception as e:
        print(f"❌ Ошибка при получении архива: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Внутренняя ошибка сервера: {str(e)}")

@router.post("/", response_model=APIResponse)
def create_single_passport(
    passport_data: PassportCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Создание одного паспорта ВЭД (синхронная сессия БД)"""
    try:
        nomenclature = db.query(VEDNomenclature).filter(VEDNomenclature.id == passport_data.nomenclature_id).first()
        if not nomenclature:
            raise HTTPException(status_code=404, detail="Номенклатура не найдена")

        created_passports = []

        for i in range(passport_data.quantity):
            if passport_data.passport_number:
                passport_number = passport_data.passport_number
                if passport_data.quantity > 1:
                    passport_number = f"{passport_data.passport_number}-{i+1:03d}"
            else:
                passport_number = VedPassport.generate_passport_number_sync(
                    db=db,
                    matrix=nomenclature.matrix or "NQ",
                    drilling_depth=nomenclature.drilling_depth,
                    article=nomenclature.article,
                    product_type=nomenclature.product_type
                )

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
            db.flush()

            created_passports.append({
                "passport_id": passport.id,
                "passport_number": passport.passport_number
            })

        db.commit()

        return APIResponse(
            success=True,
            message=f"Создано паспортов: {len(created_passports)}",
            data={"created": created_passports}
        )

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка создания паспорта: {str(e)}")

@router.post("/multiple", response_model=List[dict])
def create_multiple_passports(
    multiple_data: MultiplePassportCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Создание множественных паспортов ВЭД (синхронная сессия БД)"""
    try:
        created_passports = []

        for item in multiple_data.items:
            nomenclature = db.query(VEDNomenclature).filter(VEDNomenclature.id == item.nomenclature_id).first()
            if not nomenclature:
                raise HTTPException(status_code=404, detail=f"Номенклатура с ID {item.nomenclature_id} не найдена")

            for i in range(item.quantity):
                passport_number = VedPassport.generate_passport_number_sync(
                    db=db,
                    matrix=nomenclature.matrix or "NQ",
                    drilling_depth=nomenclature.drilling_depth,
                    article=nomenclature.article,
                    product_type=nomenclature.product_type
                )

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
                db.flush()

                created_passports.append({
                    "id": passport.id,
                    "passport_number": passport.passport_number,
                    "nomenclature_name": nomenclature.name,
                    "order_number": item.order_number,
                    "created_at": passport.created_at.isoformat()
                })

        db.commit()

        return created_passports

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка создания паспортов: {str(e)}")

@router.post("/bulk/", response_model=APIResponse)
def create_bulk_passports(
    bulk_data: BulkPassportCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Массовое создание паспортов ВЭД (синхронная сессия БД)"""
    try:
        created_passports = []
        errors = []

        for item in bulk_data.items:
            try:
                nomenclature = db.query(VEDNomenclature).filter(
                    VEDNomenclature.code_1c == item.code_1c,
                    VEDNomenclature.is_active == True
                ).first()

                if not nomenclature:
                    errors.append(f"Номенклатура с кодом {item.code_1c} не найдена")
                    continue

                for i in range(item.quantity):
                    passport_number = VedPassport.generate_passport_number_sync(
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
                    db.flush()

                    created_passports.append({
                        "id": passport.id,
                        "passport_number": passport.passport_number,
                        "order_number": passport.order_number,
                        "nomenclature": {
                            "id": nomenclature.id,
                            "code_1c": nomenclature.code_1c,
                            "name": nomenclature.name,
                            "matrix": nomenclature.matrix,
                        } if nomenclature else None,
                        "quantity": 1,
                        "status": passport.status,
                        "created_at": passport.created_at.isoformat()
                    })

            except Exception as e:
                errors.append(f"Ошибка при создании паспорта для {item.code_1c}: {str(e)}")

        db.commit()

        return APIResponse(
            success=True,
            message=f"Создано паспортов: {len(created_passports)}",
            data={
                "passports": created_passports,
                "errors": errors
            }
        )

    except Exception as e:
        db.rollback()
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
        error_msg = f"Ошибка при экспорте PDF: {e}"
        print(f"❌ {error_msg}")
        import traceback
        traceback.print_exc()
        import sys
        sys.stdout.flush()
        raise HTTPException(status_code=500, detail=error_msg)

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

@router.get("/{passport_id}/export/pdf")
async def export_passport_pdf(
    passport_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Экспорт одного паспорта в PDF"""
    try:
        passport = await db.get(VedPassport, passport_id)
        if not passport:
            raise HTTPException(status_code=404, detail="Паспорт не найден")
        
        # Проверяем права доступа
        if passport.created_by != current_user.id and current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Нет доступа к этому паспорту")
        
        # Генерируем PDF для одного паспорта
        pdf_bytes = generate_bulk_passports_pdf([passport])
        
        # Генерируем имя файла
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"passport_{passport.passport_number}_{timestamp}.pdf"
        
        return StreamingResponse(
            io.BytesIO(pdf_bytes),
            media_type="application/pdf",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Ошибка при экспорте паспорта в PDF: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Ошибка экспорта PDF: {str(e)}")

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


@router.post("/export/stickers/pdf")
async def export_stickers_pdf(
    passport_ids: List[int],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Экспорт наклеек для выбранных паспортов в PDF через reportLab (8 наклеек на страницу)"""
    try:
        if not passport_ids:
            raise HTTPException(status_code=400, detail="Не выбраны паспорта для экспорта наклеек")
        
        # Получаем выбранные паспорта с загрузкой номенклатуры
        from sqlalchemy import select
        from sqlalchemy.orm import selectinload
        passports_query = select(VedPassport).options(selectinload(VedPassport.nomenclature)).where(VedPassport.id.in_(passport_ids))
        result = await db.execute(passports_query)
        passports = result.scalars().all()
        
        # Проверяем права доступа
        accessible_passports = []
        for passport in passports:
            if passport.created_by == current_user.id or current_user.role == "admin":
                # Номенклатура уже загружена через selectinload
                accessible_passports.append(passport)
        
        if not accessible_passports:
            raise HTTPException(status_code=404, detail="Выбранные паспорта не найдены или нет доступа")
        
        print(f"📋 Экспорт наклеек: {len(accessible_passports)} паспортов")
        import sys
        sys.stdout.flush()
        
        # Генерируем PDF с наклейками через reportLab
        pdf_bytes = generate_stickers_pdf_reportlab(accessible_passports)
        
        # Генерируем имя файла с датой
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"stickers_{timestamp}.pdf"
        
        # Создаем BytesIO объект для StreamingResponse
        pdf_stream = io.BytesIO(pdf_bytes)
        
        # Принудительно устанавливаем правильные заголовки для PDF
        # ВАЖНО: filename должен быть с расширением .pdf
        if not filename.endswith('.pdf'):
            filename = filename.rsplit('.', 1)[0] + '.pdf'
        
        headers = {
            "Content-Type": "application/pdf",
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Content-Length": str(len(pdf_bytes)),
            "X-Content-Type-Options": "nosniff",
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0"
        }
        
        print(f"📤 Отправляем PDF файл: {filename}, размер: {len(pdf_bytes)} байт, Content-Type: application/pdf")
        import sys
        sys.stdout.flush()
        
        return StreamingResponse(
            pdf_stream,
            media_type="application/pdf",
            headers=headers
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Ошибка экспорта наклеек в PDF: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Ошибка экспорта наклеек в PDF: {str(e)}")


@router.post("/export/stickers/excel")
async def export_stickers_excel(
    passport_ids: List[int],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Экспорт наклеек для выбранных паспортов в Excel из шаблона с логотипом и штрихкодами"""
    try:
        if not passport_ids:
            raise HTTPException(status_code=400, detail="Не выбраны паспорта для экспорта наклеек")
        
        # Получаем выбранные паспорта с загрузкой номенклатуры
        from sqlalchemy import select
        from sqlalchemy.orm import selectinload
        passports_query = select(VedPassport).options(selectinload(VedPassport.nomenclature)).where(VedPassport.id.in_(passport_ids))
        result = await db.execute(passports_query)
        passports = result.scalars().all()
        
        # Проверяем права доступа
        accessible_passports = []
        for passport in passports:
            if passport.created_by == current_user.id or current_user.role == "admin":
                # Номенклатура уже загружена через selectinload
                accessible_passports.append(passport)
        
        if not accessible_passports:
            raise HTTPException(status_code=404, detail="Выбранные паспорта не найдены или нет доступа")
        
        print(f"📋 Экспорт наклеек (Excel из шаблона): {len(accessible_passports)} паспортов")
        import sys
        sys.stdout.flush()
        
        # Используем генерацию Excel из шаблона с логотипом и штрихкодами
        from backend.utils.sticker_excel_generator import generate_stickers_excel
        
        excel_bytes = generate_stickers_excel(accessible_passports)
        
        # Генерируем имя файла с датой
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"stickers_{timestamp}.xlsx"
        
        # Создаем BytesIO объект для StreamingResponse
        excel_stream = io.BytesIO(excel_bytes)
        
        # Убеждаемся, что filename имеет расширение .xlsx
        if not filename.endswith('.xlsx'):
            filename = filename.rsplit('.', 1)[0] + '.xlsx'
        
        # Устанавливаем правильные заголовки для Excel
        headers = {
            "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Content-Length": str(len(excel_bytes)),
            "X-Content-Type-Options": "nosniff",
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0"
        }
        
        print(f"📤 Отправляем Excel файл: {filename}, размер: {len(excel_bytes)} байт")
        import sys
        sys.stdout.flush()
        
        return StreamingResponse(
            excel_stream,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers=headers
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Ошибка экспорта наклеек в Excel: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Ошибка экспорта наклеек в Excel: {str(e)}")


@router.post("/export/stickers/docx")
async def export_stickers_docx(
    passport_ids: List[int],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Экспорт наклеек для выбранных паспортов в DOCX из шаблона с логотипом и штрихкодами"""
    try:
        if not passport_ids:
            raise HTTPException(status_code=400, detail="Не выбраны паспорта для экспорта наклеек")
        
        # Получаем выбранные паспорта с загрузкой номенклатуры
        from sqlalchemy import select
        from sqlalchemy.orm import selectinload
        passports_query = select(VedPassport).options(selectinload(VedPassport.nomenclature)).where(VedPassport.id.in_(passport_ids))
        result = await db.execute(passports_query)
        passports = result.scalars().all()
        
        # Проверяем права доступа
        accessible_passports = []
        for passport in passports:
            if passport.created_by == current_user.id or current_user.role == "admin":
                # Номенклатура уже загружена через selectinload
                accessible_passports.append(passport)
        
        if not accessible_passports:
            raise HTTPException(status_code=404, detail="Выбранные паспорта не найдены или нет доступа")
        
        print(f"📋 Экспорт наклеек (DOCX из шаблона): {len(accessible_passports)} паспортов")
        import sys
        sys.stdout.flush()
        
        # Используем генерацию DOCX из шаблона с логотипом и штрихкодами
        from backend.utils.sticker_template_generator import generate_stickers_from_template
        import zipfile
        
        docx_bytes = generate_stickers_from_template(accessible_passports)
        
        # КРИТИЧЕСКИ ВАЖНО: Проверяем, что это действительно DOCX (ZIP архив), а не PDF
        try:
            zip_buffer = io.BytesIO(docx_bytes)
            with zipfile.ZipFile(zip_buffer, 'r') as zip_check:
                if 'word/document.xml' not in zip_check.namelist():
                    raise ValueError("Результат не является валидным DOCX файлом")
            print(f"✅ Валидация DOCX пройдена: {len(docx_bytes)} байт")
            import sys
            sys.stdout.flush()
        except (zipfile.BadZipFile, ValueError) as validation_err:
            error_msg = f"Сгенерированный файл не является валидным DOCX: {validation_err}"
            print(f"❌ {error_msg}")
            import sys
            sys.stdout.flush()
            raise HTTPException(status_code=500, detail=error_msg)
        
        # Генерируем имя файла с датой
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"stickers_{timestamp}.docx"
        
        # Создаем BytesIO объект для StreamingResponse
        docx_stream = io.BytesIO(docx_bytes)
        
        # Убеждаемся, что filename имеет расширение .docx
        if not filename.endswith('.docx'):
            filename = filename.rsplit('.', 1)[0] + '.docx'
        
        # Устанавливаем правильные заголовки для DOCX
        headers = {
            "Content-Type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Content-Length": str(len(docx_bytes)),
            "X-Content-Type-Options": "nosniff",
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0"
        }
        
        print(f"📤 Отправляем DOCX файл: {filename}, размер: {len(docx_bytes)} байт, Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        import sys
        sys.stdout.flush()
        
        return StreamingResponse(
            docx_stream,
            media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            headers=headers
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Ошибка при экспорте наклеек: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Ошибка экспорта наклеек: {str(e)}")

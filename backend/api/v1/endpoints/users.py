"""
Эндпоинты для управления пользователями
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from datetime import datetime

from backend.models import User
from backend.api.schemas import UserCreate, UserResponse, UserUpdate
from backend.api.auth import get_current_user, get_admin_user
from backend.database import get_db, get_async_db

router = APIRouter()

@router.post("/", response_model=UserResponse)
async def create_user(
    user_data: UserCreate,
    current_user: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Создание нового пользователя (только для админов)"""
    try:
        # Проверяем, не существует ли уже пользователь с таким именем
        from sqlalchemy import select
        existing_user_query = select(User).where(User.username == user_data.username)
        result = await db.execute(existing_user_query)
        existing_user = result.scalar_one_or_none()
        
        if existing_user:
            raise HTTPException(status_code=400, detail="Пользователь с таким именем уже существует")
        
        # Создаем нового пользователя
        from backend.api.auth import get_password_hash
        hashed_password = get_password_hash(user_data.password)
        
        new_user = User(
            username=user_data.username,
            hashed_password=hashed_password,
            email=user_data.email,
            full_name=user_data.full_name,
            role=user_data.role or "user",
            is_active=True
        )
        
        db.add(new_user)
        await db.commit()
        await db.refresh(new_user)
        
        return new_user
        
    except Exception as e:
        await db.rollback()
        print(f"❌ Ошибка создания пользователя: {str(e)}")
        print(f"❌ Тип ошибки: {type(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Ошибка создания пользователя: {str(e)}")

@router.get("/", response_model=List[UserResponse])
async def get_users(
    current_user: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Получение списка всех пользователей (только для админов)"""
    try:
        from sqlalchemy import select
        users_query = select(User)
        result = await db.execute(users_query)
        users = result.scalars().all()
        
        return list(users)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка получения пользователей: {str(e)}")

@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Получение конкретного пользователя"""
    try:
        user = await db.get(User, user_id)
        if not user:
            raise HTTPException(status_code=404, detail="Пользователь не найден")
        
        # Проверяем права доступа
        if current_user.id != user_id and current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Нет доступа к этому пользователю")
        
        return user
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка получения пользователя: {str(e)}")

@router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: int,
    user_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Обновление пользователя"""
    try:
        user = await db.get(User, user_id)
        if not user:
            raise HTTPException(status_code=404, detail="Пользователь не найден")
        
        # Проверяем права доступа
        if current_user.id != user_id and current_user.role != "admin":
            raise HTTPException(status_code=403, detail="Нет доступа к этому пользователю")
        
        # Обновляем поля
        if user_data.email is not None:
            user.email = user_data.email
        if user_data.full_name is not None:
            user.full_name = user_data.full_name
        if user_data.role is not None and current_user.role == "admin":
            user.role = user_data.role
        if user_data.is_active is not None and current_user.role == "admin":
            user.is_active = user_data.is_active
        
        await db.commit()
        await db.refresh(user)
        
        return user
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка обновления пользователя: {str(e)}")

@router.delete("/{user_id}")
async def delete_user(
    user_id: int,
    current_user: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_async_db)
):
    """Удаление пользователя (только для админов)"""
    try:
        user = await db.get(User, user_id)
        if not user:
            raise HTTPException(status_code=404, detail="Пользователь не найден")
        
        # Нельзя удалить самого себя
        if current_user.id == user_id:
            raise HTTPException(status_code=400, detail="Нельзя удалить самого себя")
        
        await db.delete(user)
        await db.commit()
        
        return {"message": "Пользователь удален"}
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка удаления пользователя: {str(e)}")

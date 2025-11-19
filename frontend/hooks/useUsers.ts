import { useState, useEffect } from 'react'
import { usersAPI } from '../lib/api'

export interface User {
  id: number
  username: string
  email: string
  full_name: string
  role: 'admin' | 'user'
  is_active: boolean
  created_at: string
  updated_at?: string
  last_login?: string
}

export function useUsers() {
  const [users, setUsers] = useState<User[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetchUsers()
  }, [])

  const fetchUsers = async () => {
    try {
      setIsLoading(true)
      setError(null)
      const data = await usersAPI.getAll()
      setUsers(data)
    } catch (err: any) {
      const errorMessage = err.response?.data?.detail || err.message || 'Ошибка загрузки пользователей'
      setError(errorMessage)
      console.error('Error fetching users:', err)
      // Если ошибка авторизации, не показываем её как критическую
      if (err.response?.status === 401 || err.response?.status === 403) {
        console.error('Authorization error - user may not have admin rights')
      }
    } finally {
      setIsLoading(false)
    }
  }

  const createUser = async (userData: any) => {
    try {
      const response = await usersAPI.create(userData)
      await fetchUsers() // Обновляем список
      return response
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка создания пользователя')
    }
  }

  const updateUser = async (id: number, userData: any) => {
    try {
      const response = await usersAPI.update(id, userData)
      await fetchUsers() // Обновляем список
      return response
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка обновления пользователя')
    }
  }

  const deleteUser = async (id: number) => {
    try {
      await usersAPI.delete(id)
      await fetchUsers() // Обновляем список
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка удаления пользователя')
    }
  }

  return {
    users,
    isLoading,
    error,
    createUser,
    updateUser,
    deleteUser,
    refetch: fetchUsers,
  }
}

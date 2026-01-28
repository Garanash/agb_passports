import { useState, useEffect } from 'react'
import { passportsAPI } from '../lib/api'
import { NomenclatureItem } from './useNomenclature'

export interface Passport {
  id: number
  passport_number: string
  title?: string
  description?: string
  status: string
  order_number: string
  quantity: number
  created_by: number
  nomenclature_id: number
  created_at: string
  updated_at?: string
  nomenclature?: NomenclatureItem
  creator?: {
    id: number
    username: string
    email: string
    full_name: string
    role: string
  }
}

export function usePassports() {
  const [passports, setPassports] = useState<Passport[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [currentPage, setCurrentPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [totalCount, setTotalCount] = useState(0)
  const [isLoadingMore, setIsLoadingMore] = useState(false)
  const pageSize = 20

  useEffect(() => {
    fetchPassports(1)
  }, [])

  const fetchPassports = async (page: number = 1, append: boolean = false) => {
    try {
      if (append) {
        setIsLoadingMore(true)
      } else {
        setIsLoading(true)
      }
      const data = await passportsAPI.getAll(page, pageSize)
      
      // Обрабатываем новый формат ответа с пагинацией
      if (data.passports && data.pagination) {
        if (append) {
          setPassports(prev => [...prev, ...data.passports])
        } else {
          setPassports(data.passports)
        }
        setCurrentPage(data.pagination.current_page)
        setTotalPages(data.pagination.total_pages)
        setTotalCount(data.pagination.total_count)
      } else {
        // Фолбэк для старого формата
        if (Array.isArray(data)) {
          if (append) {
            setPassports(prev => [...prev, ...data])
          } else {
            setPassports(data)
          }
        } else if (data.passports) {
          if (append) {
            setPassports(prev => [...prev, ...data.passports])
          } else {
            setPassports(data.passports)
          }
        }
      }
      
      setError(null)
    } catch (err: any) {
      // Обработка ошибки 401 - неавторизован
      if (err.response?.status === 401) {
        // Очищаем токен и перенаправляем на страницу логина
        if (typeof window !== 'undefined') {
          localStorage.removeItem('token')
          localStorage.removeItem('user')
          window.location.href = '/login'
        }
        return
      }
      setError(err.response?.data?.detail || 'Ошибка загрузки паспортов')
      console.error('Error fetching passports:', err)
    } finally {
      setIsLoading(false)
      setIsLoadingMore(false)
    }
  }

  const loadMore = async () => {
    if (currentPage < totalPages && !isLoadingMore) {
      const nextPage = currentPage + 1
      await fetchPassports(nextPage, true)
    }
  }

  const createPassport = async (passportData: any) => {
    try {
      const response = await passportsAPI.create(passportData)
      await fetchPassports() // Обновляем список
      return response
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка создания паспорта')
    }
  }

  const createBulkPassports = async (bulkData: any) => {
    try {
      const response = await passportsAPI.createBulk(bulkData)
      await fetchPassports() // Обновляем список
      return response
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка массового создания паспортов')
    }
  }

  const archivePassport = async (id: number) => {
    try {
      await passportsAPI.archive(id)
      await fetchPassports() // Обновляем список
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка архивирования паспорта')
    }
  }

  const activatePassport = async (id: number) => {
    try {
      await passportsAPI.activate(id)
      await fetchPassports() // Обновляем список
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка активации паспорта')
    }
  }

  const exportPassportPdf = async (id: number) => {
    try {
      const response = await passportsAPI.exportPdf(id)
      return response
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка экспорта паспорта в PDF')
    }
  }

  const exportBulkPassportPdf = async (passportIds: number[]) => {
    try {
      const response = await passportsAPI.exportBulkPdf(passportIds)
      return response
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка экспорта паспортов в PDF')
    }
  }

  const exportPassportsExcel = async () => {
    try {
      const response = await passportsAPI.exportExcel()
      return response
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка экспорта паспортов в Excel')
    }
  }

  const exportSelectedPassportsExcel = async (passportIds: number[]) => {
    try {
      const response = await passportsAPI.exportSelectedExcel(passportIds)
      return response
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка экспорта выбранных паспортов в Excel')
    }
  }

  const exportStickersExcel = async (passportIds: number[]) => {
    try {
      const response = await passportsAPI.exportStickersExcel(passportIds)
      return response
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка экспорта наклеек')
    }
  }
  
  const exportStickersDocx = async (passportIds: number[]) => {
    try {
      const response = await passportsAPI.exportStickersDocx(passportIds)
      return response
    } catch (err: any) {
      throw new Error(err.response?.data?.detail || 'Ошибка экспорта наклеек')
    }
  }

  return {
    passports,
    isLoading,
    error,
    currentPage,
    totalPages,
    totalCount,
    isLoadingMore,
    loadMore,
    createPassport,
    createBulkPassports,
    archivePassport,
    activatePassport,
    exportPassportPdf,
    exportBulkPassportPdf,
    exportPassportsExcel,
    exportSelectedPassportsExcel,
    exportStickersExcel,
    exportStickersDocx,
    refetchPassports: fetchPassports,
    refetch: fetchPassports,
  }
}

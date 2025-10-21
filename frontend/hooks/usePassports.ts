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

  useEffect(() => {
    fetchPassports()
  }, [])

  const fetchPassports = async () => {
    try {
      setIsLoading(true)
      const data = await passportsAPI.getAll()
      setPassports(data)
      setError(null)
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Ошибка загрузки паспортов')
      console.error('Error fetching passports:', err)
    } finally {
      setIsLoading(false)
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

  return {
    passports,
    isLoading,
    error,
    createPassport,
    createBulkPassports,
    archivePassport,
    activatePassport,
    exportPassportPdf,
    exportBulkPassportPdf,
    refetchPassports: fetchPassports,
    refetch: fetchPassports,
  }
}

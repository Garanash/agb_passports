import { useState, useEffect } from 'react'
import { nomenclatureAPI } from '../lib/api'

export interface NomenclatureItem {
  id: number
  code_1c: string
  name: string
  article: string
  matrix: string
  drilling_depth?: string
  height?: string
  thread?: string
  product_type: string
}

export function useNomenclature() {
  const [nomenclature, setNomenclature] = useState<NomenclatureItem[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchNomenclature = async () => {
      try {
        setIsLoading(true)
        const data = await nomenclatureAPI.getAll()
        setNomenclature(data)
        setError(null)
      } catch (err: any) {
        setError(err.response?.data?.detail || 'Ошибка загрузки номенклатуры')
        console.error('Error fetching nomenclature:', err)
      } finally {
        setIsLoading(false)
      }
    }

    fetchNomenclature()
  }, [])

  return { nomenclature, isLoading, error, refetch: () => {
    setIsLoading(true)
    nomenclatureAPI.getAll()
      .then(data => {
        setNomenclature(data)
        setError(null)
      })
      .catch(err => {
        setError(err.response?.data?.detail || 'Ошибка загрузки номенклатуры')
      })
      .finally(() => setIsLoading(false))
  }}
}

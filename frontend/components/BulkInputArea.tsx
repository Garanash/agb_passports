'use client'

import { useState, useEffect } from 'react'
import { PlusIcon, TrashIcon } from '@heroicons/react/24/outline'

interface NomenclatureItem {
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

interface BulkInputItem {
  code_1c: string
  quantity: number
  nomenclature?: NomenclatureItem
  isValid: boolean
  error?: string
}

interface BulkInputAreaProps {
  onItemsChange: (items: BulkInputItem[]) => void
}

export default function BulkInputArea({ onItemsChange }: BulkInputAreaProps) {
  const [items, setItems] = useState<BulkInputItem[]>([])
  const [nomenclature, setNomenclature] = useState<NomenclatureItem[]>([])

  // Загружаем номенклатуру при монтировании
  useEffect(() => {
    fetchNomenclature()
  }, [])

  const fetchNomenclature = async () => {
    try {
      const response = await fetch('/api/v1/passports/nomenclature/', {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        }
      })
      
      if (response.status >= 200 && response.status < 300) {
        const data = await response.json()
        setNomenclature(data)
      }
    } catch (error) {
      console.error('Ошибка при загрузке номенклатуры:', error)
    }
  }

  const addItem = () => {
    const newItem: BulkInputItem = {
      code_1c: '',
      quantity: 1,
      isValid: false,
      error: undefined
    }
    setItems([...items, newItem])
  }

  const removeItem = (index: number) => {
    const newItems = items.filter((_, i) => i !== index)
    setItems(newItems)
    onItemsChange(newItems)
  }

  const updateItem = (index: number, field: keyof BulkInputItem, value: any) => {
    const newItems = [...items]
    newItems[index] = { ...newItems[index], [field]: value }
    
    // Валидация
    validateItem(newItems[index])
    
    setItems(newItems)
    onItemsChange(newItems)
  }

  const validateItem = (item: BulkInputItem) => {
    if (!item.code_1c.trim()) {
      item.isValid = false
      item.error = 'Введите код 1С'
      return
    }

    if (item.quantity <= 0) {
      item.isValid = false
      item.error = 'Количество должно быть больше 0'
      return
    }

    // Проверяем существование номенклатуры
    const foundNomenclature = nomenclature.find(n => n.code_1c === item.code_1c)
    if (!foundNomenclature) {
      item.isValid = false
      item.error = 'Номенклатура с таким кодом не найдена'
      return
    }

    item.nomenclature = foundNomenclature
    item.isValid = true
    item.error = undefined
  }

  const handleCodeChange = (index: number, value: string) => {
    updateItem(index, 'code_1c', value)
  }

  const handleQuantityChange = (index: number, value: number) => {
    updateItem(index, 'quantity', value)
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300">
          Позиции для создания паспортов
        </h4>
        <button
          onClick={addItem}
          className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          <PlusIcon className="h-4 w-4 mr-1" />
          Добавить позицию
        </button>
      </div>

      {items.length === 0 ? (
        <div className="text-center py-8 text-gray-500 dark:text-gray-400">
          <p>Добавьте позиции для массового создания паспортов</p>
          <p className="text-sm mt-1">Нажмите "Добавить позицию" чтобы начать</p>
        </div>
      ) : (
        <div className="space-y-3">
          {items.map((item, index) => (
            <div
              key={index}
              className={`p-4 border rounded-lg ${
                item.isValid 
                  ? 'border-green-200 bg-green-50 dark:border-green-700 dark:bg-green-900/20' 
                  : 'border-red-200 bg-red-50 dark:border-red-700 dark:bg-red-900/20'
              }`}
            >
              <div className="flex items-center space-x-4">
                <div className="flex-1">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                        Код 1С
                      </label>
                      <input
                        type="text"
                        value={item.code_1c}
                        onChange={(e) => handleCodeChange(index, e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                        placeholder="Введите код 1С"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                        Количество
                      </label>
                      <input
                        type="number"
                        min="1"
                        value={item.quantity}
                        onChange={(e) => handleQuantityChange(index, parseInt(e.target.value) || 1)}
                        className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                      />
                    </div>
                  </div>
                  
                  {item.error && (
                    <p className="mt-2 text-sm text-red-600 dark:text-red-400">{item.error}</p>
                  )}
                  
                  {item.isValid && item.nomenclature && (
                    <div className="mt-2 p-2 bg-white dark:bg-gray-800 rounded border">
                      <div className="text-sm">
                        <div className="font-medium text-gray-900 dark:text-gray-100">
                          {item.nomenclature.name}
                        </div>
                        <div className="text-gray-500 dark:text-gray-400">
                          Артикул: {item.nomenclature.article} | Матрица: {item.nomenclature.matrix}
                          {item.nomenclature.drilling_depth && ` | Глубина: ${item.nomenclature.drilling_depth}`}
                        </div>
                      </div>
                    </div>
                  )}
                </div>
                
                <button
                  onClick={() => removeItem(index)}
                  className="p-2 text-red-600 hover:text-red-800 hover:bg-red-100 dark:hover:bg-red-900/20 rounded-md"
                  title="Удалить позицию"
                >
                  <TrashIcon className="h-5 w-5" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {items.length > 0 && (
        <div className="mt-4 p-3 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-700 rounded-md">
          <div className="text-sm text-blue-800 dark:text-blue-200">
            <p className="font-medium">Сводка:</p>
            <p>Всего позиций: {items.length}</p>
            <p>Валидных позиций: {items.filter(item => item.isValid).length}</p>
            <p>Общее количество паспортов: {items.filter(item => item.isValid).reduce((sum, item) => sum + item.quantity, 0)}</p>
          </div>
        </div>
      )}
    </div>
  )
}

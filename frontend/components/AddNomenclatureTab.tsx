import React, { useState } from 'react'
import { PlusIcon } from '@heroicons/react/24/outline'
import { nomenclatureAPI } from '../lib/api'
import toast from 'react-hot-toast'

interface AddNomenclatureTabProps {
  user: any
}

export default function AddNomenclatureTab({ user }: AddNomenclatureTabProps) {
  const [newNomenclature, setNewNomenclature] = useState({
    code_1c: '',
    name: '',
    article: '',
    matrix: '',
    drilling_depth: '',
    height: '',
    thread: '',
    product_type: '',
    is_active: true
  })

  const handleCreateNomenclature = async () => {
    try {
      const result = await nomenclatureAPI.create(newNomenclature)
      toast.success('Номенклатура добавлена')
      setNewNomenclature({
        code_1c: '',
        name: '',
        article: '',
        matrix: '',
        drilling_depth: '',
        height: '',
        thread: '',
        product_type: '',
        is_active: true
      })
      window.location.reload()
    } catch (error: any) {
      console.error('Ошибка при создании номенклатуры:', error)
      toast.error(error.response?.data?.detail || 'Ошибка при создании номенклатуры')
    }
  }

  if (user?.role !== 'admin') {
    return null
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Добавить номенклатуру</h1>
        <p className="text-gray-600 mt-1">Создайте новую номенклатуру для паспортов</p>
      </div>

      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <form onSubmit={(e) => { e.preventDefault(); handleCreateNomenclature(); }}>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Код 1С *</label>
              <input
                type="text"
                value={newNomenclature.code_1c}
                onChange={(e) => setNewNomenclature({...newNomenclature, code_1c: e.target.value})}
                className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Введите код 1С"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Наименование *</label>
              <input
                type="text"
                value={newNomenclature.name}
                onChange={(e) => setNewNomenclature({...newNomenclature, name: e.target.value})}
                className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Введите наименование"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Артикул</label>
              <input
                type="text"
                value={newNomenclature.article}
                onChange={(e) => setNewNomenclature({...newNomenclature, article: e.target.value})}
                className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Введите артикул"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Матрица</label>
              <input
                type="text"
                value={newNomenclature.matrix}
                onChange={(e) => setNewNomenclature({...newNomenclature, matrix: e.target.value})}
                className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Введите матрицу"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Глубина бурения</label>
              <input
                type="text"
                value={newNomenclature.drilling_depth}
                onChange={(e) => setNewNomenclature({...newNomenclature, drilling_depth: e.target.value})}
                className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Введите глубину бурения"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Высота</label>
              <input
                type="text"
                value={newNomenclature.height}
                onChange={(e) => setNewNomenclature({...newNomenclature, height: e.target.value})}
                className="block w-full px-3 py ниж2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Введите высоту"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Резьба</label>
              <input
                type="text"
                value={newNomenclature.thread}
                onChange={(e) => setNewNomenclature({...newNomenclature, thread: e.target.value})}
                className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Введите резьбу"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Тип продукта *</label>
              <input
                type="text"
                value={newNomenclature.product_type}
                onChange={(e) => setNewNomenclature({...newNomenclature, product_type: e.target.value})}
                className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Введите тип продукта"
                required
              />
            </div>

            <div>
              <label className="flex items-center">
                <input
                  type="checkbox"
                  checked={newNomenclature.is_active}
                  onChange={(e) => setNewNomenclature({...newNomenclature, is_active: e.target.checked})}
                  className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
                <span className="ml-2 text-sm text-gray-700">Активна</span>
              </label>
            </div>
          </div>

          <div className="flex justify-end space-x-3 mt-6">
            <button
              type="submit"
              className="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700"
            >
              <PlusIcon className="h-5 w-5 mr-2" />
              Добавить номенклатуру
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}


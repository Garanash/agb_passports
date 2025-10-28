import React, { useState } from 'react'
import { PlusIcon, ArrowLeftIcon, DocumentArrowUpIcon } from '@heroicons/react/24/outline'
import { nomenclatureAPI } from '../lib/api'
import toast from 'react-hot-toast'
import { useAuth } from '../contexts/AuthContext'
import ProtectedRoute from '../components/ProtectedRoute'
import { useRouter } from 'next/router'
import * as XLSX from 'xlsx'

function AddNomenclaturePage() {
  const { user } = useAuth()
  const router = useRouter()
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
  const [isUploading, setIsUploading] = useState(false)

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    setIsUploading(true)
    try {
      const data = await file.arrayBuffer()
      const workbook = XLSX.read(data, { type: 'array' })
      const firstSheet = workbook.Sheets[workbook.SheetNames[0]]
      const jsonData = XLSX.utils.sheet_to_json(firstSheet) as any[]

      let successCount = 0
      let errorCount = 0

      for (const row of jsonData) {
        try {
          const nomenclature = {
            code_1c: String(row['Код 1С'] || row['code_1c'] || ''),
            name: String(row['Наименование'] || row['name'] || ''),
            article: String(row['Артикул'] || row['article'] || ''),
            matrix: String(row['Матрица'] || row['matrix'] || ''),
            drilling_depth: String(row['Глубина бурения'] || row['drilling_depth'] || ''),
            height: String(row['Высота'] || row['height'] || ''),
            thread: String(row['Резьба'] || row['thread'] || ''),
            product_type: String(row['Тип продукта'] || row['product_type'] || 'Коронка'),
            is_active: true
          }

          if (nomenclature.code_1c && nomenclature.name) {
            await nomenclatureAPI.create(nomenclature)
            successCount++
          }
        } catch (error: any) {
          console.error('Ошибка при создании номенклатуры:', error)
          errorCount++
        }
      }

      toast.success(`Загружено успешно: ${successCount}, ошибок: ${errorCount}`)
      event.target.value = '' // Сбрасываем input
    } catch (error) {
      console.error('Ошибка при обработке файла:', error)
      toast.error('Ошибка при обработке файла')
    } finally {
      setIsUploading(false)
    }
  }

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
    } catch (error: any) {
      console.error('Ошибка при создании номенклатуры:', error)
      toast.error(error.response?.data?.detail || 'Ошибка при создании номенклатуры')
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Верхняя панель */}
      <div className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-4">
              <button
                onClick={() => router.push('/')}
                className="flex items-center px-3 py-2 text-sm font-medium text-gray-700 hover:text-gray-900 hover:bg-gray-100 rounded-md transition-colors duration-200"
              >
                <ArrowLeftIcon className="h-4 w-4 mr-2" />
                Назад
              </button>
              <h1 className="text-xl font-semibold text-gray-900">Добавить номенклатуру</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-600">
                {user?.full_name || user?.username}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Основной контент */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="max-w-4xl mx-auto">
          <div className="mb-6">
            <p className="text-gray-600 mt-1">Создайте новую номенклатуру для паспортов или загрузите из Excel</p>
          </div>

          {/* Кнопка загрузки файла */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6 mb-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-semibold text-gray-900 mb-2">Загрузить из Excel</h2>
                <p className="text-sm text-gray-600">Загрузите файл Excel с номенклатурой</p>
              </div>
              <label className="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 cursor-pointer">
                <DocumentArrowUpIcon className="h-5 w-5 mr-2" />
                {isUploading ? 'Загрузка...' : 'Загрузить файл'}
                <input
                  type="file"
                  accept=".xlsx,.xls"
                  onChange={handleFileUpload}
                  disabled={isUploading}
                  className="hidden"
                />
              </label>
            </div>
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
                  className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
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
      </main>
    </div>
  )
}

export default function AddNomenclaturePageWrapper() {
  return (
    <ProtectedRoute>
      <AddNomenclaturePage />
    </ProtectedRoute>
  )
}


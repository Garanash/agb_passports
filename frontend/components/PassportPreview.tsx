'use client'

import { XMarkIcon } from '@heroicons/react/24/outline'

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

interface PassportPreviewProps {
  passport: {
    id: number
    passport_number: string
    order_number: string
    nomenclature: NomenclatureItem
    quantity: number
    status: string
    created_at: string
  }
  isOpen: boolean
  onClose: () => void
}

export default function PassportPreview({ passport, isOpen, onClose }: PassportPreviewProps) {
  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
      <div className="relative top-10 mx-auto p-8 border w-11/12 md:w-3/4 lg:w-2/3 xl:w-1/2 shadow-lg rounded-lg bg-white">
        <div className="relative">
          {/* Кнопка закрытия */}
          <button
            onClick={onClose}
            className="absolute top-0 right-0 text-gray-400 hover:text-gray-600"
          >
            <XMarkIcon className="h-6 w-6" />
          </button>

          {/* Заголовок */}
          <div className="text-center mb-6">
            <h2 className="text-xl font-bold text-gray-800 mb-2">
              Предварительный просмотр паспорта
            </h2>
            <h1 className="text-2xl font-bold text-gray-900 mb-4">
              ООО "Алмазгеобур"
            </h1>
            <div className="text-sm text-gray-600 space-y-1">
              <p>125362, г. Москва, улица Водников, дом 2, стр. 14, оф. 11</p>
              <p>тел.: +7 495 229 82 94</p>
              <p>e-mail: contact@almazgeobur.ru</p>
            </div>
          </div>

          {/* Разделительная линия */}
          <hr className="border-gray-300 mb-6" />

          {/* Заголовок паспорта */}
          <div className="mb-6">
            <h3 className="text-lg font-bold text-gray-800 mb-3">
              Паспорт бурового оборудования
            </h3>
            <p className="text-sm text-gray-700">
              Номер паспорта: <span className="font-mono font-semibold">{passport.passport_number}</span>
            </p>
          </div>

          {/* Таблица с данными */}
          <div className="mb-6">
            <div className="border border-gray-200 rounded-lg overflow-hidden">
              <div className="bg-gray-50 px-4 py-3 border-b border-gray-200">
                <h4 className="font-medium text-gray-700">Характеристики оборудования</h4>
              </div>
              <div className="divide-y divide-gray-200">
                <div className="flex">
                  <div className="w-1/3 bg-gray-50 px-4 py-3 font-medium text-gray-700 border-r border-gray-200">
                    Код 1С
                  </div>
                  <div className="w-2/3 px-4 py-3 text-gray-900">
                    {passport.nomenclature.code_1c}
                  </div>
                </div>
                <div className="flex">
                  <div className="w-1/3 bg-gray-50 px-4 py-3 font-medium text-gray-700 border-r border-gray-200">
                    Наименование
                  </div>
                  <div className="w-2/3 px-4 py-3 text-gray-900">
                    {passport.nomenclature.name}
                  </div>
                </div>
                <div className="flex">
                  <div className="w-1/3 bg-gray-50 px-4 py-3 font-medium text-gray-700 border-r border-gray-200">
                    Артикул
                  </div>
                  <div className="w-2/3 px-4 py-3 text-gray-900">
                    {passport.nomenclature.article}
                  </div>
                </div>
                <div className="flex">
                  <div className="w-1/3 bg-gray-50 px-4 py-3 font-medium text-gray-700 border-r border-gray-200">
                    Матрица
                  </div>
                  <div className="w-2/3 px-4 py-3 text-gray-900">
                    {passport.nomenclature.matrix}
                  </div>
                </div>
                {passport.nomenclature.drilling_depth && (
                  <div className="flex">
                    <div className="w-1/3 bg-gray-50 px-4 py-3 font-medium text-gray-700 border-r border-gray-200">
                      Глубина бурения
                    </div>
                    <div className="w-2/3 px-4 py-3 text-gray-900">
                      {passport.nomenclature.drilling_depth}
                    </div>
                  </div>
                )}
                {passport.nomenclature.height && (
                  <div className="flex">
                    <div className="w-1/3 bg-gray-50 px-4 py-3 font-medium text-gray-700 border-r border-gray-200">
                      Высота
                    </div>
                    <div className="w-2/3 px-4 py-3 text-gray-900">
                      {passport.nomenclature.height}
                    </div>
                  </div>
                )}
                {passport.nomenclature.thread && (
                  <div className="flex">
                    <div className="w-1/3 bg-gray-50 px-4 py-3 font-medium text-gray-700 border-r border-gray-200">
                      Резьба
                    </div>
                    <div className="w-2/3 px-4 py-3 text-gray-900">
                      {passport.nomenclature.thread}
                    </div>
                  </div>
                )}
                <div className="flex">
                  <div className="w-1/3 bg-gray-50 px-4 py-3 font-medium text-gray-700 border-r border-gray-200">
                    Тип продукта
                  </div>
                  <div className="w-2/3 px-4 py-3 text-gray-900">
                    {passport.nomenclature.product_type}
                  </div>
                </div>
                <div className="flex">
                  <div className="w-1/3 bg-gray-50 px-4 py-3 font-medium text-gray-700 border-r border-gray-200">
                    Количество
                  </div>
                  <div className="w-2/3 px-4 py-3 text-gray-900">
                    {passport.quantity} шт
                  </div>
                </div>
                <div className="flex">
                  <div className="w-1/3 bg-gray-50 px-4 py-3 font-medium text-gray-700 border-r border-gray-200">
                    Номер заказа поставщику
                  </div>
                  <div className="w-2/3 px-4 py-3 text-gray-900">
                    {passport.order_number}
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Подвал */}
          <div className="flex justify-between items-end">
            <div className="text-sm text-gray-600">
              Дата создания: {new Date(passport.created_at).toLocaleDateString('ru-RU')}
            </div>
            <button
              onClick={onClose}
              className="px-6 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
            >
              Закрыть
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

import { useState, useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { useNomenclature } from '../hooks/useNomenclature'
import { usePassports } from '../hooks/usePassports'
import { useAuth } from '../contexts/AuthContext'
import { 
  DocumentTextIcon, 
  PlusIcon, 
  CheckCircleIcon,
  ExclamationTriangleIcon,
  MagnifyingGlassIcon,
  XMarkIcon
} from '@heroicons/react/24/outline'
import toast from 'react-hot-toast'

interface FormData {
  nomenclature_id: number
  order_number: string
  quantity: number
  title?: string
  description?: string
}

export default function CreatePassportForm() {
  const { nomenclature, isLoading: nomenclatureLoading } = useNomenclature()
  const { refetchPassports } = usePassports()
  const { user } = useAuth()
  const [selectedNomenclature, setSelectedNomenclature] = useState<any>(null)
  const [searchTerm, setSearchTerm] = useState('')
  const [showNomenclatureList, setShowNomenclatureList] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch,
    reset
  } = useForm<FormData>({
    defaultValues: {
      quantity: 1,
      order_number: '',
      title: '',
      description: ''
    }
  })

  const watchedNomenclatureId = watch('nomenclature_id')

  // Фильтрация номенклатуры по поисковому запросу
  const filteredNomenclature = nomenclature.filter(item =>
    item.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    item.code_1c.toLowerCase().includes(searchTerm.toLowerCase()) ||
    item.article.toLowerCase().includes(searchTerm.toLowerCase())
  )

  // Обновление выбранной номенклатуры при изменении ID
  useEffect(() => {
    if (watchedNomenclatureId && nomenclature.length > 0) {
      const selected = nomenclature.find(item => item.id === watchedNomenclatureId)
      setSelectedNomenclature(selected)
    }
  }, [watchedNomenclatureId, nomenclature])

  const onSubmit = async (data: FormData) => {
    if (!data.nomenclature_id) {
      toast.error('Пожалуйста, выберите номенклатуру')
      return
    }

    setIsSubmitting(true)
    try {
      const response = await fetch('/api/v1/passports/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        },
        body: JSON.stringify(data)
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.detail || 'Ошибка при создании паспорта')
      }

      const result = await response.json()
      toast.success('Паспорт успешно создан!')
      reset()
      setSelectedNomenclature(null)
      setSearchTerm('')
      refetchPassports()
    } catch (error: any) {
      console.error('Ошибка при создании паспорта:', error)
      toast.error(error.message || 'Ошибка при создании паспорта')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleNomenclatureSelect = (item: any) => {
    setValue('nomenclature_id', item.id)
    setSelectedNomenclature(item)
    setSearchTerm(item.name)
    setShowNomenclatureList(false)
  }

  const clearSelection = () => {
    setValue('nomenclature_id', 0)
    setSelectedNomenclature(null)
    setSearchTerm('')
    setShowNomenclatureList(false)
  }

  if (nomenclatureLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="loading-spinner h-8 w-8"></div>
        <span className="ml-2 text-gray-600">Загрузка номенклатуры...</span>
      </div>
    )
  }

  return (
    <div className="max-w-3xl mx-auto">
      {/* Заголовок */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Создание паспорта</h1>
        <p className="text-gray-600 mt-1">Создайте новый паспорт ВЭД для номенклатуры</p>
      </div>

      {/* Форма */}
      <div className="card">
        <div className="card-header">
          <h2 className="text-xl font-semibold text-gray-900">Информация о паспорте</h2>
          <p className="text-sm text-gray-600 mt-1">Заполните все необходимые поля для создания паспорта</p>
        </div>
        
        <div className="card-body">
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
            {/* Выбор номенклатуры */}
            <div className="space-y-2">
              <label className="form-label">
                Номенклатура <span className="text-red-500">*</span>
              </label>
              
              <div className="relative">
                <div className="relative">
                  <MagnifyingGlassIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
                  <input
                    type="text"
                    placeholder="Поиск номенклатуры по названию, коду или артикулу..."
                    value={searchTerm}
                    onChange={(e) => {
                      setSearchTerm(e.target.value)
                      setShowNomenclatureList(true)
                    }}
                    onFocus={() => setShowNomenclatureList(true)}
                    className="form-input pl-10 pr-10"
                  />
                  {selectedNomenclature && (
                    <button
                      type="button"
                      onClick={clearSelection}
                      className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                    >
                      <XMarkIcon className="h-5 w-5" />
                    </button>
                  )}
                </div>

                {/* Список номенклатуры */}
                {showNomenclatureList && (
                  <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg max-h-60 overflow-y-auto">
                    {filteredNomenclature.length === 0 ? (
                      <div className="px-4 py-3 text-sm text-gray-500">
                        Номенклатура не найдена
                      </div>
                    ) : (
                      filteredNomenclature.map((item) => (
                        <button
                          key={item.id}
                          type="button"
                          onClick={() => handleNomenclatureSelect(item)}
                          className="w-full px-4 py-3 text-left hover:bg-gray-50 border-b border-gray-100 last:border-b-0"
                        >
                          <div className="flex items-center justify-between">
                            <div className="flex-1">
                              <div className="text-sm font-medium text-gray-900">{item.name}</div>
                              <div className="text-xs text-gray-500 mt-1">
                                Код: {item.code_1c} | Артикул: {item.article}
                              </div>
                            </div>
                            <DocumentTextIcon className="h-5 w-5 text-gray-400" />
                          </div>
                        </button>
                      ))
                    )}
                  </div>
                )}
              </div>

              {/* Выбранная номенклатура */}
              {selectedNomenclature && (
                <div className="mt-3 p-4 bg-blue-50 border border-blue-200 rounded-md">
                  <div className="flex items-start space-x-3">
                    <CheckCircleIcon className="h-5 w-5 text-blue-600 mt-0.5" />
                    <div className="flex-1">
                      <h3 className="text-sm font-medium text-blue-900">Выбранная номенклатура</h3>
                      <div className="mt-1 text-sm text-blue-800">
                        <div className="font-medium">{selectedNomenclature.name}</div>
                        <div className="text-xs mt-1">
                          Код 1С: {selectedNomenclature.code_1c} | 
                          Артикул: {selectedNomenclature.article} | 
                          Тип: {selectedNomenclature.product_type}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {errors.nomenclature_id && (
                <p className="form-error">Пожалуйста, выберите номенклатуру</p>
              )}
            </div>

            {/* Номер заказа */}
            <div className="space-y-2">
              <label className="form-label">
                Номер заказа <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                {...register('order_number', { 
                  required: 'Номер заказа обязателен',
                  minLength: { value: 3, message: 'Минимум 3 символа' }
                })}
                className="form-input"
                placeholder="Введите номер заказа"
              />
              {errors.order_number && (
                <p className="form-error">{errors.order_number.message}</p>
              )}
            </div>

            {/* Количество */}
            <div className="space-y-2">
              <label className="form-label">
                Количество <span className="text-red-500">*</span>
              </label>
              <input
                type="number"
                min="1"
                {...register('quantity', { 
                  required: 'Количество обязательно',
                  min: { value: 1, message: 'Минимум 1' }
                })}
                className="form-input"
                placeholder="Введите количество"
              />
              {errors.quantity && (
                <p className="form-error">{errors.quantity.message}</p>
              )}
            </div>

            {/* Название паспорта */}
            <div className="space-y-2">
              <label className="form-label">Название паспорта</label>
              <input
                type="text"
                {...register('title')}
                className="form-input"
                placeholder="Введите название паспорта (необязательно)"
              />
              <p className="form-help">Если не указано, будет использовано название номенклатуры</p>
            </div>

            {/* Описание */}
            <div className="space-y-2">
              <label className="form-label">Описание</label>
              <textarea
                {...register('description')}
                rows={3}
                className="form-input"
                placeholder="Введите описание паспорта (необязательно)"
              />
            </div>

            {/* Кнопки */}
            <div className="flex items-center justify-end space-x-3 pt-6 border-t border-gray-200">
              <button
                type="button"
                onClick={() => {
                  reset()
                  setSelectedNomenclature(null)
                  setSearchTerm('')
                }}
                className="btn btn-secondary"
                disabled={isSubmitting}
              >
                Очистить
              </button>
              <button
                type="submit"
                className="btn btn-primary"
                disabled={isSubmitting || !selectedNomenclature}
              >
                {isSubmitting ? (
                  <>
                    <div className="loading-spinner h-4 w-4 mr-2"></div>
                    Создание...
                  </>
                ) : (
                  <>
                    <PlusIcon className="h-4 w-4 mr-2" />
                    Создать паспорт
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      </div>

      {/* Информация о пользователе */}
      <div className="mt-6 card">
        <div className="card-body">
          <div className="flex items-center space-x-3">
            <div className="h-10 w-10 bg-gray-100 rounded-full flex items-center justify-center">
              <DocumentTextIcon className="h-5 w-5 text-gray-600" />
            </div>
            <div>
              <h3 className="text-sm font-medium text-gray-900">Информация о создателе</h3>
              <p className="text-sm text-gray-600">
                Паспорт будет создан от имени: <span className="font-medium">{user?.full_name || user?.username}</span>
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

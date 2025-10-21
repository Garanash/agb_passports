import { useState, useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { useNomenclature } from '../hooks/useNomenclature'
import { usePassports } from '../hooks/usePassports'
import { useAuth } from '../contexts/AuthContext'
import { useRouter } from 'next/router'
import * as XLSX from 'xlsx'
import { 
  DocumentTextIcon, 
  PlusIcon, 
  CheckCircleIcon,
  MagnifyingGlassIcon,
  XMarkIcon,
  HomeIcon,
  ArchiveBoxIcon,
  UserGroupIcon,
  Cog6ToothIcon,
  ArrowDownTrayIcon,
  DocumentArrowDownIcon
} from '@heroicons/react/24/outline'
import toast from 'react-hot-toast'

interface FormData {
  nomenclature_id: number
  quantity: number
}

interface SelectedItem {
  id: number
  name: string
  code_1c: string
  article: string
  product_type: string
  quantity: number
}

interface OrderData {
  order_number: string
}

export default function MainApp() {
  const { nomenclature, isLoading: nomenclatureLoading } = useNomenclature()
  const { passports, refetchPassports } = usePassports()
  const { user, logout } = useAuth()
  const router = useRouter()
  const [activeTab, setActiveTab] = useState('create')
  const [selectedItems, setSelectedItems] = useState<SelectedItem[]>([])
  const [searchTerm, setSearchTerm] = useState('')
  const [showNomenclatureList, setShowNomenclatureList] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [orderNumber, setOrderNumber] = useState('')
  const [createdPassports, setCreatedPassports] = useState<any[]>([])
  const [showCreateUserModal, setShowCreateUserModal] = useState(false)
  const [users, setUsers] = useState<any[]>([])
  const [isLoadingUsers, setIsLoadingUsers] = useState(false)
  const [editingUser, setEditingUser] = useState<any>(null)
  const [showEditUserModal, setShowEditUserModal] = useState(false)

  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch,
    reset
  } = useForm<FormData>({
    defaultValues: {
      quantity: 1
    }
  })

  const watchedNomenclatureId = watch('nomenclature_id')
  const watchedQuantity = watch('quantity')

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
      if (selected) {
        setSearchTerm(selected.name)
      }
    }
  }, [watchedNomenclatureId, nomenclature])

  useEffect(() => {
    if (activeTab === 'users' && user?.role === 'admin') {
      loadUsers()
    }
  }, [activeTab, user?.role])

  const addToSelection = () => {
    if (!orderNumber || orderNumber.length < 6) {
      toast.error('Номер заказа должен содержать не менее 6 символов')
      return
    }

    if (!watchedNomenclatureId || !watchedQuantity) {
      toast.error('Выберите номенклатуру и укажите количество')
      return
    }

    const selectedNomenclature = nomenclature.find(item => item.id === watchedNomenclatureId)
    if (!selectedNomenclature) {
      toast.error('Номенклатура не найдена')
      return
    }

    const newItem: SelectedItem = {
      id: selectedNomenclature.id,
      name: selectedNomenclature.name,
      code_1c: selectedNomenclature.code_1c,
      article: selectedNomenclature.article,
      product_type: selectedNomenclature.product_type,
      quantity: watchedQuantity
    }

    setSelectedItems(prev => [...prev, newItem])
    reset()
    setSearchTerm('')
    toast.success('Элемент добавлен в список')
  }

  const removeFromSelection = (index: number) => {
    setSelectedItems(prev => prev.filter((_, i) => i !== index))
  }

  const createPassports = async () => {
    if (!orderNumber || orderNumber.length < 6) {
      toast.error('Номер заказа должен содержать не менее 6 символов')
      return
    }

    if (selectedItems.length === 0) {
      toast.error('Добавьте хотя бы один элемент')
      return
    }

    // Проверяем токен аутентификации
    const token = localStorage.getItem('token')
    if (!token) {
      toast.error('Необходимо войти в систему')
      router.push('/login')
      return
    }

    setIsSubmitting(true)
    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'}/api/v1/passports/multiple`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          items: selectedItems.map(item => ({
            nomenclature_id: item.id,
            order_number: orderNumber,
            quantity: Number(item.quantity) || 1
          }))
        })
      })

      if (!response.ok) {
        if (response.status === 401) {
          toast.error('Сессия истекла. Необходимо войти в систему')
          localStorage.removeItem('token')
          router.push('/login')
          return
        }
        const errorData = await response.json()
        throw new Error(errorData.detail || 'Ошибка при создании паспортов')
      }

      const result = await response.json()
      toast.success(`Создано ${result.length} паспортов!`)
      setCreatedPassports(result)
      setSelectedItems([])
      setOrderNumber('')
      refetchPassports()
    } catch (error: any) {
      console.error('Ошибка при создании паспортов:', error)
      toast.error(error.message || 'Ошибка при создании паспортов')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleNomenclatureSelect = (item: any) => {
    setValue('nomenclature_id', item.id)
    setSearchTerm(item.name)
    setShowNomenclatureList(false)
  }

  const clearSelection = () => {
    setValue('nomenclature_id', 0)
    setSearchTerm('')
    setShowNomenclatureList(false)
  }

  const exportToExcel = () => {
    if (createdPassports.length === 0) {
      toast('Сначала создайте паспорта')
      return
    }

    // Подготавливаем данные для Excel
    const excelData = createdPassports.map((passport, index) => ({
      '№': index + 1,
      'Номер паспорта': passport.passport_number,
      'Номенклатура': passport.nomenclature_name,
      'Номер заказа': passport.order_number,
      'Дата создания': new Date(passport.created_at).toLocaleDateString('ru-RU'),
      'Время создания': new Date(passport.created_at).toLocaleTimeString('ru-RU')
    }))

    // Создаем рабочую книгу Excel
    const wb = XLSX.utils.book_new()
    const ws = XLSX.utils.json_to_sheet(excelData)

    // Настраиваем ширину колонок
    const colWidths = [
      { wch: 5 },   // №
      { wch: 25 },  // Номер паспорта
      { wch: 40 },  // Номенклатура
      { wch: 15 },  // Номер заказа
      { wch: 12 },  // Дата создания
      { wch: 12 }   // Время создания
    ]
    ws['!cols'] = colWidths

    // Добавляем лист в книгу
    XLSX.utils.book_append_sheet(wb, ws, 'Паспорта')

    // Генерируем Excel файл
    const excelBuffer = XLSX.write(wb, { bookType: 'xlsx', type: 'array' })
    
    // Создаем и скачиваем файл
    const blob = new Blob([excelBuffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' })
    const link = document.createElement('a')
    const url = URL.createObjectURL(blob)
    link.setAttribute('href', url)
    link.setAttribute('download', `passports_${orderNumber}_${new Date().toISOString().split('T')[0]}.xlsx`)
    link.style.visibility = 'hidden'
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    
    toast('Файл Excel экспортирован')
  }

  const exportToPdf = async (passportIds?: number[]) => {
    const idsToExport = passportIds || (createdPassports.length > 0 ? createdPassports.map(passport => passport.id) : [])
    
    if (idsToExport.length === 0) {
      toast('Сначала создайте паспорта')
      return
    }

    // Проверяем токен аутентификации
    const token = localStorage.getItem('token')
    if (!token) {
      toast.error('Необходимо войти в систему')
      router.push('/login')
      return
    }

    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'}/api/v1/passports/export/bulk/pdf`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(idsToExport)
      })

      if (!response.ok) {
        if (response.status === 401) {
          toast.error('Сессия истекла. Необходимо войти в систему')
          localStorage.removeItem('token')
          router.push('/login')
          return
        }
        throw new Error('Ошибка при экспорте PDF')
      }

      // Создаем blob из ответа
      const blob = await response.blob()
      
      // Создаем ссылку для скачивания
      const url = window.URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `passports_${new Date().toISOString().split('T')[0]}.pdf`
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      window.URL.revokeObjectURL(url)
      
      toast.success('PDF файл экспортирован')
    } catch (error: any) {
      console.error('Ошибка при экспорте PDF:', error)
      toast.error(error.message || 'Ошибка при экспорте PDF')
    }
  }

  const archivePassport = async (passportId: number) => {
    const token = localStorage.getItem('token')
    if (!token) {
      toast.error('Необходимо войти в систему')
      router.push('/login')
      return
    }

    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'}/api/v1/passports/${passportId}/archive`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      })

      if (!response.ok) {
        if (response.status === 401) {
          toast.error('Сессия истекла. Необходимо войти в систему')
          localStorage.removeItem('token')
          router.push('/login')
          return
        }
        throw new Error('Ошибка при архивировании паспорта')
      }

      toast.success('Паспорт архивирован')
      refetchPassports()
    } catch (error: any) {
      console.error('Ошибка при архивировании паспорта:', error)
      toast.error(error.message || 'Ошибка при архивировании паспорта')
    }
  }

  const loadUsers = async () => {
    console.log('loadUsers вызвана')
    const token = localStorage.getItem('token')
    if (!token) {
      toast.error('Необходимо войти в систему')
      router.push('/login')
      return
    }

    setIsLoadingUsers(true)
    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'}/api/v1/users/`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      })

      if (!response.ok) {
        if (response.status === 401) {
          toast.error('Сессия истекла. Необходимо войти в систему')
          localStorage.removeItem('token')
          router.push('/login')
          return
        }
        throw new Error('Ошибка при загрузке пользователей')
      }

      const usersData = await response.json()
      console.log('Загружены пользователи:', usersData)
      setUsers(usersData)
    } catch (error: any) {
      console.error('Ошибка при загрузке пользователей:', error)
      toast.error(error.message || 'Ошибка при загрузке пользователей')
    } finally {
      setIsLoadingUsers(false)
    }
  }

  const editUser = (user: any) => {
    setEditingUser(user)
    setShowEditUserModal(true)
  }

  const deleteUser = async (userId: number) => {
    console.log('deleteUser вызвана с ID:', userId)
    if (!confirm('Вы уверены, что хотите удалить этого пользователя?')) {
      return
    }

    const token = localStorage.getItem('token')
    if (!token) {
      toast.error('Необходимо войти в систему')
      router.push('/login')
      return
    }

    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'}/api/v1/users/${userId}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      })

      if (!response.ok) {
        if (response.status === 401) {
          toast.error('Сессия истекла. Необходимо войти в систему')
          localStorage.removeItem('token')
          router.push('/login')
          return
        }
        throw new Error('Ошибка при удалении пользователя')
      }

      toast.success('Пользователь удален')
      loadUsers() // Перезагружаем список
    } catch (error: any) {
      console.error('Ошибка при удалении пользователя:', error)
      toast.error(error.message || 'Ошибка при удалении пользователя')
    }
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
    <div className="min-h-screen bg-gray-50">
      {/* Верхняя панель */}
      <div className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <h1 className="text-xl font-semibold text-gray-900">AGB Passports</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-600">
                {user?.full_name || user?.username}
              </span>
              <button
                onClick={() => {
                  localStorage.removeItem('token')
                  window.location.href = '/login'
                }}
                className="flex items-center px-3 py-2 text-sm font-medium text-gray-700 hover:text-gray-900 hover:bg-gray-100 rounded-md transition-colors duration-200"
              >
                <ArrowDownTrayIcon className="h-4 w-4 mr-2" />
                Выйти
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="flex">
        {/* Боковое меню */}
        <div className="w-64 bg-white shadow-sm border-r border-gray-200 min-h-screen">
          <nav className="mt-8">
            <div className="px-4 space-y-2">
              <button
                onClick={() => setActiveTab('create')}
                className={`w-full flex items-center px-4 py-2 text-sm font-medium rounded-md transition-colors duration-200 ${
                  activeTab === 'create'
                    ? 'bg-blue-100 text-blue-700'
                    : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
                }`}
              >
                <PlusIcon className="h-5 w-5 mr-3" />
                Создание паспорта
              </button>
              <button
                onClick={() => setActiveTab('archive')}
                className={`w-full flex items-center px-4 py-2 text-sm font-medium rounded-md transition-colors duration-200 ${
                  activeTab === 'archive'
                    ? 'bg-blue-100 text-blue-700'
                    : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
                }`}
              >
                <ArchiveBoxIcon className="h-5 w-5 mr-3" />
                Архив паспортов
              </button>
              {user?.role === 'admin' && (
                <button
                  onClick={() => setActiveTab('users')}
                  className={`w-full flex items-center px-4 py-2 text-sm font-medium rounded-md transition-colors duration-200 ${
                    activeTab === 'users'
                      ? 'bg-blue-100 text-blue-700'
                      : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
                  }`}
                >
                  <UserGroupIcon className="h-5 w-5 mr-3" />
                  Пользователи
                </button>
              )}
            </div>
          </nav>
        </div>

        {/* Основной контент */}
        <div className="flex-1 p-8">
          {activeTab === 'create' && (
            <div className="max-w-4xl mx-auto">
              <div className="mb-6">
                <h1 className="text-2xl font-bold text-gray-900">Создание паспортов</h1>
                <p className="text-gray-600 mt-1">Добавьте номенклатуру и создайте паспорта</p>
              </div>

              {/* Номер заказа */}
              <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6 mb-6">
                <h2 className="text-lg font-semibold text-gray-900 mb-4">Номер заказа</h2>
                
                <div className="max-w-md">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Номер заказа <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={orderNumber}
                    onChange={(e) => setOrderNumber(e.target.value)}
                    className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    placeholder="Введите номер заказа (минимум 6 символов)"
                    minLength={6}
                  />
                  {orderNumber && orderNumber.length < 6 && (
                    <p className="mt-1 text-sm text-red-600">Номер заказа должен содержать не менее 6 символов</p>
                  )}
                </div>
              </div>

              {/* Форма добавления */}
              <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6 mb-6">
                <h2 className="text-lg font-semibold text-gray-900 mb-4">Добавить номенклатуру</h2>
                
                {/* Таблица с номенклатурой */}
                <div className="space-y-4">
                  {/* Заголовки таблицы */}
                  <div className="grid grid-cols-12 gap-4 text-sm font-medium text-gray-700 border-b border-gray-200 pb-2">
                    <div className="col-span-6">Номенклатура</div>
                    <div className="col-span-2">Код</div>
                    <div className="col-span-2">Артикул</div>
                    <div className="col-span-1">Кол-во</div>
                    <div className="col-span-1">Действия</div>
                  </div>

                  {/* Строки с номенклатурой */}
                  {selectedItems.map((item, index) => (
                    <div key={index} className="grid grid-cols-12 gap-4 items-center py-2 border-b border-gray-100">
                      <div className="col-span-6">
                        <div className="text-sm font-medium text-gray-900">{item.name}</div>
                        <div className="text-xs text-gray-500">{item.product_type}</div>
                      </div>
                      <div className="col-span-2 text-sm text-gray-600">{item.code_1c}</div>
                      <div className="col-span-2 text-sm text-gray-600">{item.article}</div>
                      <div className="col-span-1">
                        <input
                          type="number"
                          min="1"
                          value={item.quantity}
                          onChange={(e) => {
                            const newQuantity = parseInt(e.target.value) || 1
                            setSelectedItems(prev => prev.map((itm, idx) => 
                              idx === index ? { ...itm, quantity: newQuantity } : itm
                            ))
                          }}
                          className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                        />
                      </div>
                      <div className="col-span-1">
                        <button
                          onClick={() => removeFromSelection(index)}
                          className="text-red-600 hover:text-red-800"
                        >
                          <XMarkIcon className="h-4 w-4" />
                        </button>
                      </div>
                    </div>
                  ))}

                  {/* Строка для добавления новой номенклатуры */}
                  <div className="grid grid-cols-12 gap-4 items-center py-2 bg-gray-50 rounded-md px-3">
                    <div className="col-span-6">
                      <div className="relative">
                        <MagnifyingGlassIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                        <input
                          type="text"
                          placeholder="Поиск номенклатуры..."
                          value={searchTerm}
                          onChange={(e) => {
                            setSearchTerm(e.target.value)
                            setShowNomenclatureList(true)
                          }}
                          onFocus={() => setShowNomenclatureList(true)}
                          className="block w-full px-3 py-2 pl-10 pr-10 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        />
                        {watchedNomenclatureId && (
                          <button
                            type="button"
                            onClick={clearSelection}
                            className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                          >
                            <XMarkIcon className="h-4 w-4" />
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
                    <div className="col-span-2 text-sm text-gray-500">-</div>
                    <div className="col-span-2 text-sm text-gray-500">-</div>
                    <div className="col-span-1">
                      <input
                        type="number"
                        min="1"
                        {...register('quantity', { 
                          required: 'Количество обязательно',
                          min: { value: 1, message: 'Минимум 1' }
                        })}
                        className="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                        placeholder="1"
                      />
                    </div>
                    <div className="col-span-1">
                      <button
                        type="button"
                        onClick={addToSelection}
                        disabled={!orderNumber || orderNumber.length < 6 || !watchedNomenclatureId}
                        className="px-3 py-1 bg-blue-600 text-white text-sm font-medium rounded hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        <PlusIcon className="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                </div>

                {/* Итоговая информация и кнопка создания */}
                {selectedItems.length > 0 && (
                  <div className="mt-6 pt-4 border-t border-gray-200">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="text-sm text-gray-600">
                          Заказ: <span className="font-medium">{orderNumber}</span>
                        </p>
                        <p className="text-sm text-blue-600 mt-1">
                          Будет создано паспортов: <span className="font-bold">
                            {selectedItems.reduce((total, item) => {
                              const currentQuantity = Number(item.quantity) || 0
                              console.log('Calculating:', total, '+', currentQuantity, '=', total + currentQuantity)
                              return total + currentQuantity
                            }, 0)}
                          </span>
                        </p>
                      </div>
                      <div className="flex space-x-3">
                        <button
                          onClick={exportToExcel}
                          className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200"
                        >
                          <DocumentArrowDownIcon className="h-4 w-4 mr-2" />
                          Excel
                        </button>
                        <button
                          onClick={() => exportToPdf()}
                          className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200"
                        >
                          <DocumentArrowDownIcon className="h-4 w-4 mr-2" />
                          PDF
                        </button>
                        <button
                          onClick={createPassports}
                          disabled={isSubmitting}
                          className="inline-flex items-center px-6 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {isSubmitting ? (
                            <>
                              <div className="loading-spinner h-4 w-4 mr-2"></div>
                              Создание...
                            </>
                          ) : (
                            <>
                              <PlusIcon className="h-4 w-4 mr-2" />
                              Создать {selectedItems.reduce((total, item) => total + (Number(item.quantity) || 0), 0)} паспорт(ов)
                            </>
                          )}
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </div>


              {/* Список созданных паспортов */}
              {createdPassports.length > 0 && (
                <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6 mb-6">
                  <div className="flex items-center justify-between mb-4">
                    <div>
                      <h2 className="text-lg font-semibold text-gray-900">
                        Созданные паспорта ({createdPassports.length})
                      </h2>
                      <p className="text-sm text-green-600 mt-1">
                        ✅ Паспорта успешно созданы
                      </p>
                    </div>
                    <div className="flex space-x-2">
                      <button
                        onClick={exportToExcel}
                        className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200"
                      >
                        <DocumentArrowDownIcon className="h-4 w-4 mr-2" />
                        Excel
                      </button>
                      <button
                        onClick={() => exportToPdf()}
                        className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200"
                      >
                        <DocumentArrowDownIcon className="h-4 w-4 mr-2" />
                        PDF
                      </button>
                    </div>
                  </div>

                  <div className="space-y-3">
                    {createdPassports.map((passport, index) => (
                      <div key={index} className="flex items-center justify-between p-4 bg-green-50 border border-green-200 rounded-md">
                        <div className="flex-1">
                          <div className="text-sm font-medium text-gray-900">
                            {passport.passport_number}
                          </div>
                          <div className="text-xs text-gray-500 mt-1">
                            Номенклатура: {passport.nomenclature_name}
                          </div>
                          <div className="text-xs text-gray-500">
                            Заказ: {passport.order_number} | Создан: {new Date(passport.created_at).toLocaleString('ru-RU')}
                          </div>
                        </div>
                        <div className="text-green-600">
                          <CheckCircleIcon className="h-5 w-5" />
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}

                 {activeTab === 'archive' && (
                   <div className="max-w-6xl mx-auto">
                     <div className="mb-6">
                       <h1 className="text-2xl font-bold text-gray-900">Архив паспортов</h1>
                       <p className="text-gray-600 mt-1">Просмотр всех созданных паспортов</p>
                     </div>

                     <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                       {passports.length === 0 ? (
                         <div className="text-center py-12">
                           <ArchiveBoxIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                           <h3 className="text-lg font-medium text-gray-900 mb-2">Архив пуст</h3>
                           <p className="text-gray-600">Создайте паспорта, чтобы они появились в архиве</p>
                         </div>
                       ) : (
                         <div className="space-y-4">
                           <div className="flex items-center justify-between">
                             <h3 className="text-lg font-semibold text-gray-900">
                               Всего паспортов: {passports.length}
                             </h3>
                             <div className="flex space-x-2">
                               <button
                                 onClick={() => {
                                   const allIds = passports.map(p => p.id)
                                   exportToPdf(allIds)
                                 }}
                                 className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200"
                               >
                                 <DocumentArrowDownIcon className="h-4 w-4 mr-2" />
                                 Экспорт всех в PDF
                               </button>
                             </div>
                           </div>
                           
                           <div className="overflow-x-auto">
                             <table className="min-w-full divide-y divide-gray-200">
                               <thead className="bg-gray-50">
                                 <tr>
                                   <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                     Номер паспорта
                                   </th>
                                   <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                     Номенклатура
                                   </th>
                                   <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                     Номер заказа
                                   </th>
                                   <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                     Статус
                                   </th>
                                   <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                     Создан
                                   </th>
                                   <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                     Действия
                                   </th>
                                 </tr>
                               </thead>
                               <tbody className="bg-white divide-y divide-gray-200">
                                 {passports.map((passport) => (
                                   <tr key={passport.id} className="hover:bg-gray-50">
                                     <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                       {passport.passport_number}
                                     </td>
                                     <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                       {passport.nomenclature?.name || 'Не указано'}
                                     </td>
                                     <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                       {passport.order_number}
                                     </td>
                                     <td className="px-6 py-4 whitespace-nowrap">
                                       <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                                         passport.status === 'active' 
                                           ? 'bg-green-100 text-green-800' 
                                           : 'bg-gray-100 text-gray-800'
                                       }`}>
                                         {passport.status === 'active' ? 'Активный' : 'Архивный'}
                                       </span>
                                     </td>
                                     <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                       {new Date(passport.created_at).toLocaleDateString('ru-RU')}
                                     </td>
                                     <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                       <button
                                         onClick={() => exportToPdf([passport.id])}
                                         className="text-blue-600 hover:text-blue-900 mr-3"
                                       >
                                         PDF
                                       </button>
                                       {passport.status === 'active' && (
                                         <button
                                           onClick={() => archivePassport(passport.id)}
                                           className="text-orange-600 hover:text-orange-900"
                                         >
                                           Архивировать
                                         </button>
                                       )}
                                     </td>
                                   </tr>
                                 ))}
                               </tbody>
                             </table>
                           </div>
                         </div>
                       )}
                     </div>
                   </div>
                 )}

          {activeTab === 'users' && user?.role === 'admin' && (
            <div className="max-w-6xl mx-auto">
              <div className="mb-6">
                <h1 className="text-2xl font-bold text-gray-900">Управление пользователями</h1>
                <p className="text-gray-600 mt-1">Создание и управление пользователями системы</p>
              </div>

              <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                <div className="mb-6">
                  <button
                    onClick={() => setShowCreateUserModal(true)}
                    className="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                  >
                    <PlusIcon className="h-4 w-4 mr-2" />
                    Создать пользователя
                  </button>
                </div>

                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Имя пользователя
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Полное имя
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Email
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Роль
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Статус
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Последний вход
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Действия
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {isLoadingUsers ? (
                        <tr>
                          <td colSpan={7} className="px-6 py-4 text-center">
                            <div className="flex items-center justify-center">
                              <div className="loading-spinner h-4 w-4 mr-2"></div>
                              Загрузка пользователей...
                            </div>
                          </td>
                        </tr>
                      ) : users.length === 0 ? (
                        <tr>
                          <td colSpan={7} className="px-6 py-4 text-center text-gray-500">
                            Пользователи не найдены
                          </td>
                        </tr>
                      ) : (
                        users.map((userItem) => (
                          <tr key={userItem.id} className="hover:bg-gray-50">
                            <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                              {userItem.username}
                              {userItem.id === user?.id && (
                                <span className="ml-2 text-xs text-blue-600">(Вы)</span>
                              )}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {userItem.full_name || 'Не указано'}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {userItem.email || 'Не указано'}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap">
                              <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                                userItem.role === 'admin' 
                                  ? 'bg-purple-100 text-purple-800' 
                                  : 'bg-blue-100 text-blue-800'
                              }`}>
                                {userItem.role === 'admin' ? 'Администратор' : 'Пользователь'}
                              </span>
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap">
                              <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                                userItem.is_active 
                                  ? 'bg-green-100 text-green-800' 
                                  : 'bg-red-100 text-red-800'
                              }`}>
                                {userItem.is_active ? 'Активный' : 'Заблокирован'}
                              </span>
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {userItem.last_login 
                                ? new Date(userItem.last_login).toLocaleDateString('ru-RU')
                                : 'Никогда'
                              }
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                              {userItem.id === user?.id ? (
                                <span className="text-gray-400">Текущий пользователь</span>
                              ) : (
                                <div className="flex space-x-2">
                                  <button
                                    onClick={(e) => {
                                      console.log('Кнопка Редактировать нажата для пользователя:', userItem)
                                      e.preventDefault()
                                      editUser(userItem)
                                    }}
                                    className="text-blue-600 hover:text-blue-900"
                                  >
                                    Редактировать
                                  </button>
                                  <button
                                    onClick={(e) => {
                                      console.log('Кнопка Удалить нажата для пользователя ID:', userItem.id)
                                      e.preventDefault()
                                      deleteUser(userItem.id)
                                    }}
                                    className="text-red-600 hover:text-red-900"
                                  >
                                    Удалить
                                  </button>
                                </div>
                              )}
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Модальное окно создания пользователя */}
      {showCreateUserModal && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-medium text-gray-900">Создать пользователя</h3>
                <button
                  onClick={() => setShowCreateUserModal(false)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <XMarkIcon className="h-6 w-6" />
                </button>
              </div>
              
              <form onSubmit={async (e) => {
                e.preventDefault()
                const formData = new FormData(e.target as HTMLFormElement)
                const username = formData.get('username') as string
                const password = formData.get('password') as string
                const fullName = formData.get('fullName') as string
                const role = formData.get('role') as string

                const token = localStorage.getItem('token')
                if (!token) {
                  toast.error('Необходимо войти в систему')
                  return
                }

                try {
                  const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'}/api/v1/users/`, {
                    method: 'POST',
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': `Bearer ${token}`
                    },
                    body: JSON.stringify({
                      username,
                      password,
                      full_name: fullName,
                      role: role || 'user'
                    })
                  })

                  if (!response.ok) {
                    if (response.status === 401) {
                      toast.error('Сессия истекла. Необходимо войти в систему')
                      localStorage.removeItem('token')
                      router.push('/login')
                      return
                    }
                    const errorData = await response.json()
                    throw new Error(errorData.detail || 'Ошибка при создании пользователя')
                  }

                  toast.success('Пользователь создан успешно')
                  setShowCreateUserModal(false)
                  loadUsers() // Перезагружаем список пользователей
                } catch (error: any) {
                  console.error('Ошибка при создании пользователя:', error)
                  toast.error(error.message || 'Ошибка при создании пользователя')
                }
              }}>
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Имя пользователя *
                    </label>
                    <input
                      type="text"
                      name="username"
                      required
                      className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Введите имя пользователя"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Пароль *
                    </label>
                    <input
                      type="password"
                      name="password"
                      required
                      className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Введите пароль"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Полное имя
                    </label>
                    <input
                      type="text"
                      name="fullName"
                      className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Введите полное имя"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Роль
                    </label>
                    <select
                      name="role"
                      className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="user">Пользователь</option>
                      <option value="admin">Администратор</option>
                    </select>
                  </div>
                </div>
                
                <div className="flex justify-end space-x-3 mt-6">
                  <button
                    type="button"
                    onClick={() => setShowCreateUserModal(false)}
                    className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200"
                  >
                    Отмена
                  </button>
                  <button
                    type="submit"
                    className="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700"
                  >
                    Создать
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* Модальное окно редактирования пользователя */}
      {showEditUserModal && editingUser && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-medium text-gray-900">Редактировать пользователя</h3>
                <button
                  onClick={() => {
                    setShowEditUserModal(false)
                    setEditingUser(null)
                  }}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <XMarkIcon className="h-6 w-6" />
                </button>
              </div>
              
              <form onSubmit={async (e) => {
                e.preventDefault()
                const formData = new FormData(e.target as HTMLFormElement)
                const username = formData.get('username') as string
                const password = formData.get('password') as string
                const fullName = formData.get('fullName') as string
                const role = formData.get('role') as string

                const token = localStorage.getItem('token')
                if (!token) {
                  toast.error('Необходимо войти в систему')
                  return
                }

                try {
                  const updateData: any = {
                    username,
                    full_name: fullName,
                    role: role || 'user'
                  }

                  // Добавляем пароль только если он указан
                  if (password && password.trim()) {
                    updateData.password = password
                  }

                  const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'}/api/v1/users/${editingUser.id}`, {
                    method: 'PUT',
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': `Bearer ${token}`
                    },
                    body: JSON.stringify(updateData)
                  })

                  if (!response.ok) {
                    if (response.status === 401) {
                      toast.error('Сессия истекла. Необходимо войти в систему')
                      localStorage.removeItem('token')
                      router.push('/login')
                      return
                    }
                    const errorData = await response.json()
                    throw new Error(errorData.detail || 'Ошибка при обновлении пользователя')
                  }

                  toast.success('Пользователь обновлен успешно')
                  setShowEditUserModal(false)
                  setEditingUser(null)
                  loadUsers() // Перезагружаем список пользователей
                } catch (error: any) {
                  console.error('Ошибка при обновлении пользователя:', error)
                  toast.error(error.message || 'Ошибка при обновлении пользователя')
                }
              }}>
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Имя пользователя *
                    </label>
                    <input
                      type="text"
                      name="username"
                      required
                      defaultValue={editingUser.username}
                      className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Введите имя пользователя"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Пароль (оставьте пустым, чтобы не изменять)
                    </label>
                    <input
                      type="password"
                      name="password"
                      className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Введите новый пароль"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Полное имя
                    </label>
                    <input
                      type="text"
                      name="fullName"
                      defaultValue={editingUser.full_name || ''}
                      className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Введите полное имя"
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Роль
                    </label>
                    <select
                      name="role"
                      defaultValue={editingUser.role}
                      className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="user">Пользователь</option>
                      <option value="admin">Администратор</option>
                    </select>
                  </div>
                </div>
                
                <div className="flex justify-end space-x-3 mt-6">
                  <button
                    type="button"
                    onClick={() => {
                      setShowEditUserModal(false)
                      setEditingUser(null)
                    }}
                    className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200"
                  >
                    Отмена
                  </button>
                  <button
                    type="submit"
                    className="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700"
                  >
                    Сохранить
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

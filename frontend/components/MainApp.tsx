import React, { useState, useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { useNomenclature } from '../hooks/useNomenclature'
import { usePassports } from '../hooks/usePassports'
import { useAuth } from '../contexts/AuthContext'
import { useRouter } from 'next/router'
import * as XLSX from 'xlsx'
import { passportsAPI, nomenclatureAPI } from '../lib/api'
import AddNomenclatureTab from './AddNomenclatureTab'
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
  DocumentArrowDownIcon,
  TableCellsIcon
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
  const { passports, refetchPassports, exportSelectedPassportsExcel, currentPage, totalPages, totalCount, isLoadingMore, loadMore } = usePassports()
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
  const [archiveSearchTerm, setArchiveSearchTerm] = useState('')
  const [selectedPassportIds, setSelectedPassportIds] = useState<number[]>([])
  const [showArchived, setShowArchived] = useState(false)

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

  // Фильтрация паспортов по поисковому запросу архива и статусу
  const filteredPassports = passports.filter(passport => {
    // В архиве показываем ВСЕ паспорта по умолчанию
    // Если включен фильтр "показывать архивные", показываем только архивные
    if (showArchived && passport.status !== 'archived') {
      return false
    }
    // Если фильтр НЕ включен, показываем активные (по умолчанию)
    // Но в архиве всегда показываем активные для удобства просмотра
    // Убираем фильтрацию по статусу для корректной работы архива

    // Фильтр по поисковому запросу
    if (!archiveSearchTerm) return true

    const searchLower = archiveSearchTerm.toLowerCase()
    return (
      passport.passport_number?.toLowerCase().includes(searchLower) ||
      passport.order_number?.toLowerCase().includes(searchLower) ||
      passport.nomenclature?.name?.toLowerCase().includes(searchLower) ||
      passport.nomenclature?.code_1c?.toLowerCase().includes(searchLower) ||
      passport.nomenclature?.article?.toLowerCase().includes(searchLower)
    )
  })

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

  // Очищаем выбор при изменении поискового запроса или фильтра архива
  useEffect(() => {
    setSelectedPassportIds([])
  }, [archiveSearchTerm, showArchived])

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

    try {
      const response = await passportsAPI.exportBulkPdf(idsToExport)
      
      // Создаем blob из ответа
      const blob = new Blob([response], { type: 'application/pdf' })
      
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

  const handleExportExcel = async () => {
    try {
      const blob = await passportsAPI.exportExcel()
      const url = window.URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `ved_passports_export_${new Date().toISOString().slice(0, 10)}.xlsx`
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      window.URL.revokeObjectURL(url)
      toast.success('Паспорта успешно экспортированы в Excel')
    } catch (error: any) {
      console.error('Ошибка при экспорте Excel:', error)
      toast.error('Ошибка экспорта паспортов в Excel')
    }
  }

  // Функции для работы с выбором паспортов
  const togglePassportSelection = (passportId: number) => {
    console.log('togglePassportSelection called with passportId:', passportId)
    setSelectedPassportIds(prev => {
      const newSelection = prev.includes(passportId) 
        ? prev.filter(id => id !== passportId)
        : [...prev, passportId]
      console.log('New selection:', newSelection)
      return newSelection
    })
  }

  const selectAllPassports = () => {
    console.log('selectAllPassports called, filteredPassports:', filteredPassports.length)
    setSelectedPassportIds(filteredPassports.map(p => p.id))
  }

  const deselectAllPassports = () => {
    setSelectedPassportIds([])
  }

  const exportSelectedToPdf = async () => {
    if (selectedPassportIds.length === 0) {
      toast.error('Выберите паспорта для экспорта')
      return
    }
    await exportToPdf(selectedPassportIds)
  }

  const exportSelectedToExcel = async () => {
    if (selectedPassportIds.length === 0) {
      toast.error('Выберите паспорта для экспорта')
      return
    }
    try {
      const blob = await exportSelectedPassportsExcel(selectedPassportIds)
      const url = window.URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `ved_passports_selected_${new Date().toISOString().slice(0, 10)}.xlsx`
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      window.URL.revokeObjectURL(url)
      toast.success(`Экспортировано ${selectedPassportIds.length} паспортов в Excel`)
    } catch (error: any) {
      console.error('Ошибка при экспорте Excel:', error)
      toast.error('Ошибка экспорта паспортов в Excel')
    }
  }

  const archivePassport = async (passportId: number) => {
    try {
      await passportsAPI.archive(passportId)
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
              <div className="flex items-center space-x-3">
                <svg width="60" height="18" viewBox="0 0 180 53" fill="none" xmlns="http://www.w3.org/2000/svg" className="text-[#FBBA00]">
                  <g clip-path="url(#clip0_791_2649)">
                    <path fill-rule="evenodd" clip-rule="evenodd" d="M28.316 0C32.3097 0.364122 36.0417 1.65878 39.3096 3.66651C39.0776 4.03569 38.9443 4.48072 38.9443 4.95105C38.9443 6.27605 39.9958 7.35324 41.2892 7.35324C42.0099 7.35324 42.6566 7.01946 43.0861 6.49351C45.9739 9.08788 48.299 12.3346 49.8392 16.0011C48.9753 16.3552 48.3583 17.2199 48.3583 18.2314C48.3583 19.5564 49.4097 20.6336 50.7031 20.6336C50.9055 20.6336 51.103 20.6083 51.2906 20.5577C51.7151 22.4694 51.9422 24.4569 51.9422 26.5C51.9422 28.5431 51.725 30.4548 51.3152 32.3361C51.1178 32.2804 50.9104 32.2501 50.6932 32.2501C49.3999 32.2501 48.3484 33.3273 48.3484 34.6523C48.3484 35.684 48.9852 36.5639 49.8787 36.9028C48.3484 40.5946 46.0233 43.8565 43.1305 46.466C42.701 45.8996 42.0297 45.5304 41.2744 45.5304C39.981 45.5304 38.9295 46.6076 38.9295 47.9326C38.9295 48.4434 39.0826 48.9137 39.3491 49.3031C36.0713 51.326 32.3195 52.6308 28.3062 53C28.3062 51.6801 27.2547 50.6079 25.9613 50.6079C24.668 50.6079 23.6214 51.68 23.6165 53.0051C19.6475 52.6409 15.9353 51.3614 12.6821 49.3739C12.9734 48.9744 13.1461 48.4738 13.1461 47.9377C13.1461 46.6127 12.0947 45.5355 10.8013 45.5355C10.0115 45.5355 9.31047 45.935 8.88593 46.552C5.95858 43.9374 3.61374 40.6552 2.06368 36.9432C3.02136 36.6398 3.71741 35.7295 3.71741 34.6472C3.71741 33.3222 2.66593 32.245 1.37256 32.245C1.11093 32.245 0.854231 32.2906 0.617279 32.3715C0.202612 30.4801 -0.0195312 28.5178 -0.0195312 26.4949C-0.0195312 24.472 0.207548 22.434 0.641961 20.5072C0.873977 20.583 1.11587 20.6235 1.37256 20.6235C2.66593 20.6235 3.71741 19.5513 3.71741 18.2213C3.71741 17.1593 3.04111 16.254 2.10317 15.9405C3.65817 12.2537 6.00795 8.99685 8.93036 6.39742C9.35984 6.97395 10.0361 7.34313 10.7964 7.34313C12.0897 7.34313 13.1412 6.27099 13.1412 4.94094C13.1412 4.44027 12.9882 3.96994 12.7315 3.58559C15.9896 1.62844 19.6821 0.359065 23.6313 0C23.6807 1.28454 24.7075 2.30611 25.9712 2.30611C27.2349 2.30611 28.2667 1.28454 28.316 0ZM25.9712 3.45916C13.5509 3.45916 3.48539 13.776 3.48539 26.5C3.48539 39.224 13.5559 49.5408 25.9761 49.5408C38.3964 49.5408 48.4669 39.224 48.4669 26.5C48.4669 13.776 38.3915 3.45916 25.9712 3.45916Z" fill="currentColor"/>
                    <path fill-rule="evenodd" clip-rule="evenodd" d="M40.2478 10.6152C40.8994 10.6355 41.1956 10.9187 41.5511 11.4547L48.3931 21.0433L25.9665 49.7988L3.5498 21.0433L10.3918 11.4547C10.7472 10.9187 11.0434 10.6355 11.695 10.6152C21.2126 10.6152 30.7302 10.6152 40.2478 10.6152ZM17.6386 21.7108H6.76841C6.31425 21.7007 6.0773 22.2419 6.36362 22.5857L22.896 43.6138C23.2366 44.069 23.9475 43.7149 23.8092 43.1586L18.1174 22.075C18.0533 21.8676 17.8608 21.7159 17.6386 21.7058V21.7108ZM34.2105 21.7108C33.9883 21.7159 33.7958 21.8676 33.7316 22.08L28.0398 43.1637C27.8967 43.72 28.6125 44.074 28.9531 43.6189L45.4855 22.5857C45.7767 22.2419 45.5348 21.7007 45.0807 21.7108H34.2105ZM31.6237 21.7108H20.2796C19.9341 21.7108 19.6823 22.0547 19.7811 22.3936L25.4778 43.4419C25.6209 43.9526 26.3318 43.9526 26.475 43.4419L32.1322 22.3936C32.2063 22.1104 31.9101 21.7159 31.6237 21.7159V21.7108ZM16.6316 19.3896L11.8876 12.6634C11.7987 12.542 11.6457 12.4611 11.4778 12.4611C11.31 12.4611 11.157 12.542 11.0681 12.6634L6.32412 19.3896C6.10198 19.6879 6.334 20.0976 6.72892 20.1026H16.2317C16.6316 20.1026 16.8586 19.6879 16.6365 19.3946L16.6316 19.3896ZM23.8685 12.4207C24.0906 12.1274 23.8685 11.7127 23.4637 11.7127H13.9609C13.566 11.7127 13.334 12.1274 13.5561 12.4257L18.3001 19.1519C18.389 19.2732 18.542 19.3542 18.7098 19.3542C18.8777 19.3542 19.0307 19.2732 19.1196 19.1519L23.8635 12.4257L23.8685 12.4207ZM31.1202 19.3896L26.3762 12.6634C26.2874 12.542 26.1343 12.4611 25.9665 12.4611C25.7987 12.4611 25.6456 12.542 25.5568 12.6634L20.8128 19.3896C20.5906 19.6879 20.8227 20.0976 21.2176 20.1026H30.7204C31.1202 20.1026 31.3473 19.6879 31.1252 19.3946L31.1202 19.3896ZM45.5299 19.4047L40.7859 12.6786C40.6971 12.5572 40.544 12.4763 40.3762 12.4763C40.2083 12.4763 40.0553 12.5572 39.9664 12.6786L35.2225 19.4047C35.0003 19.7031 35.2323 20.1128 35.6273 20.1178H45.13C45.5299 20.1178 45.757 19.7031 45.5348 19.4098L45.5299 19.4047ZM28.0053 12.3954L32.7493 19.1215C32.8381 19.2429 32.9912 19.3238 33.159 19.3238C33.3268 19.3238 33.4799 19.2429 33.5687 19.1215L38.3127 12.3954C38.5349 12.097 38.3028 11.6874 37.9079 11.6823H28.4051C28.0053 11.6823 27.7782 12.097 28.0003 12.3903L28.0053 12.3954Z" fill="currentColor"/>
                  </g>
                  <defs>
                    <clipPath id="clip0_791_2649">
                      <rect width="180" height="53" fill="white"/>
                    </clipPath>
                  </defs>
                </svg>
                <h1 className="text-xl font-semibold text-gray-900">AGB Passports</h1>
              </div>
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
                <>
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
                  <button
                    onClick={() => setActiveTab('add_nomenclature')}
                    className={`w-full flex items-center px-4 py-2 text-sm font-medium rounded-md transition-colors duration-200 ${
                      activeTab === 'add_nomenclature'
                        ? 'bg-blue-100 text-blue-700'
                        : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
                    }`}
                  >
                    <PlusIcon className="h-5 w-5 mr-3" />
                    Добавить номенклатуру
                  </button>
                </>
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
                      {filteredPassports.length === 0 ? (
                        archiveSearchTerm ? (
                          <div className="text-center py-12">
                            <MagnifyingGlassIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                            <h3 className="text-lg font-medium text-gray-900 mb-2">Ничего не найдено</h3>
                            <p className="text-gray-600">Попробуйте изменить поисковый запрос</p>
                            <button
                              onClick={() => setArchiveSearchTerm('')}
                              className="mt-4 inline-flex items-center px-3 py-2 text-sm font-medium text-blue-600 bg-blue-50 border border-blue-200 rounded-md hover:bg-blue-100"
                            >
                              Очистить поиск
                            </button>
                          </div>
                        ) : (
                          <div className="text-center py-12">
                            <ArchiveBoxIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                            <h3 className="text-lg font-medium text-gray-900 mb-2">Архив пуст</h3>
                            <p className="text-gray-600">Создайте паспорта, чтобы они появились в архиве</p>
                          </div>
                        )
                      ) : (
                         <div className="space-y-4">
                           <div className="flex items-center justify-between">
                             <div>
                               <h3 className="text-lg font-semibold text-gray-900">
                                 {archiveSearchTerm ? `Найдено паспортов: ${filteredPassports.length}` : `Всего паспортов: ${passports.length}`}
                               </h3>
                               {archiveSearchTerm && (
                                 <p className="text-sm text-gray-600 mt-1">
                                   Поиск: "{archiveSearchTerm}"
                                 </p>
                               )}
                             </div>
                             <div className="flex flex-wrap gap-2">
                               {/* Кнопки выбора */}
                               <div className="flex space-x-2">
                                 <button
                                   onClick={selectAllPassports}
                                   className="inline-flex items-center px-3 py-2 text-sm font-medium text-blue-700 bg-blue-100 border border-blue-300 rounded-md hover:bg-blue-200"
                                 >
                                   Выбрать все
                                 </button>
                                 <button
                                   onClick={deselectAllPassports}
                                   className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200"
                                 >
                                   Снять выбор
                                 </button>
                               </div>
                               
                               {/* Кнопки экспорта выбранных */}
                               <div className="flex space-x-2">
                                 <button
                                   onClick={exportSelectedToPdf}
                                   disabled={selectedPassportIds.length === 0}
                                   className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed"
                                 >
                                   <DocumentArrowDownIcon className="h-4 w-4 mr-2" />
                                   Экспорт выбранных в PDF ({selectedPassportIds.length})
                                 </button>
                                 <button
                                   onClick={exportSelectedToExcel}
                                   disabled={selectedPassportIds.length === 0}
                                   className="inline-flex items-center px-3 py-2 text-sm font-medium text-white bg-green-600 border border-green-600 rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
                                 >
                                   <TableCellsIcon className="h-4 w-4 mr-2" />
                                   Экспорт выбранных в Excel ({selectedPassportIds.length})
                                 </button>
                               </div>
                               
                               {/* Кнопки экспорта всех */}
                               <div className="flex space-x-2">
                                 <button
                                   onClick={() => {
                                     const allIds = filteredPassports.map(p => p.id)
                                     exportToPdf(allIds)
                                   }}
                                   className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200"
                                 >
                                   <DocumentArrowDownIcon className="h-4 w-4 mr-2" />
                                   Экспорт всех в PDF
                                 </button>
                                 <button
                                   onClick={handleExportExcel}
                                   className="inline-flex items-center px-3 py-2 text-sm font-medium text-white bg-green-600 border border-green-600 rounded-md hover:bg-green-700"
                                 >
                                   <TableCellsIcon className="h-4 w-4 mr-2" />
                                   Экспорт всех в Excel
                                 </button>
                               </div>
                             </div>
                           </div>

                           {/* Строка поиска и фильтры */}
                           <div className="space-y-4">
                             <div className="relative">
                               <MagnifyingGlassIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
                               <input
                                 type="text"
                                 placeholder="Поиск по номеру паспорта, заказу или номенклатуре..."
                                 value={archiveSearchTerm}
                                 onChange={(e) => setArchiveSearchTerm(e.target.value)}
                                 className="block w-full px-3 py-2 pl-10 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                               />
                             </div>
                             
                             {/* Фильтры */}
                             <div className="flex items-center space-x-4">
                               <label className="flex items-center">
                                 <input
                                   type="checkbox"
                                   checked={showArchived}
                                   onChange={(e) => setShowArchived(e.target.checked)}
                                   className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                                 />
                                 <span className="ml-2 text-sm text-gray-700">Показывать архивные</span>
                               </label>
                             </div>
                           </div>
                           
                           <div className="overflow-x-auto">
                             <table className="min-w-full divide-y divide-gray-200">
                               <thead className="bg-gray-50">
                                 <tr>
                                   <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-12">
                                     <input
                                       type="checkbox"
                                       checked={selectedPassportIds.length === filteredPassports.length && filteredPassports.length > 0}
                                       onChange={(e) => e.target.checked ? selectAllPassports() : deselectAllPassports()}
                                       className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                                     />
                                   </th>
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
                                 {filteredPassports.map((passport) => (
                                   <tr key={passport.id} className="hover:bg-gray-50">
                                     <td className="px-6 py-4 whitespace-nowrap w-12">
                                       <input
                                         type="checkbox"
                                         checked={selectedPassportIds.includes(passport.id)}
                                         onChange={() => togglePassportSelection(passport.id)}
                                         className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                                       />
                                     </td>
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
                           {currentPage < totalPages && (
                             <div className="flex justify-center mt-6">
                               <button
                                 onClick={loadMore}
                                 disabled={isLoadingMore}
                                 className="inline-flex items-center px-4 py-2 text-sm font-medium text-blue-600 bg-blue-50 border border-blue-200 rounded-md hover:bg-blue-100 disabled:opacity-50 disabled:cursor-not-allowed"
                               >
                                 {isLoadingMore ? (
                                   <>
                                     <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                       <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                                       <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                     </svg>
                                     Загрузка...
                                   </>
                                 ) : (
                                   <>
                                     <PlusIcon className="h-5 w-5 mr-2" />
                                     Загрузить ещё (показано {filteredPassports.length} из {totalCount})
                                   </>
                                 )}
                               </button>
                             </div>
                           )}
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
                                    onClick={() => {
                                      console.log('Кнопка Редактировать нажата для пользователя:', userItem)
                                      editUser(userItem)
                                    }}
                                    className="text-blue-600 hover:text-blue-900"
                                  >
                                    Редактировать
                                  </button>
                                  <button
                                    onClick={() => {
                                      console.log('Кнопка Удалить нажата для пользователя ID:', userItem.id)
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
                const email = formData.get('email') as string
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
                      email: email || null,
                      role: role || 'user',
                      is_active: true
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
                      Email
                    </label>
                    <input
                      type="email"
                      name="email"
                      className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Введите email (необязательно)"
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
                const email = formData.get('email') as string
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
                    email: email || null,
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
                      Email
                    </label>
                    <input
                      type="email"
                      name="email"
                      defaultValue={editingUser.email || ''}
                      className="block w-full px-3 py-2 text-sm border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Введите email (необязательно)"
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

      {/* Вкладка добавления номенклатуры */}
      {activeTab === 'add_nomenclature' && user?.role === 'admin' && (
        <AddNomenclatureTab user={user} />
      )}
    </div>
  )
}

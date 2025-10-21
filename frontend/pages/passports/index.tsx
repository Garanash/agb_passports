import { useState } from 'react'
import { usePassports } from '../../hooks/usePassports'
import { useAuth } from '../../contexts/AuthContext'
import { 
  DocumentTextIcon, 
  EyeIcon,
  ArchiveBoxIcon,
  ArrowDownTrayIcon,
  PlusIcon,
  MagnifyingGlassIcon,
  CalendarIcon,
  UserIcon,
  TagIcon,
  CheckCircleIcon,
  ExclamationTriangleIcon
} from '@heroicons/react/24/outline'
import Link from 'next/link'
import toast from 'react-hot-toast'

export default function PassportsPage() {
  const [searchTerm, setSearchTerm] = useState('')
  const { passports, isLoading, error, refetchPassports, archivePassport, exportPassportPdf } = usePassports()
  const { user, isAdmin } = useAuth()

  // Фильтрация паспортов по роли пользователя
  const filteredPassports = passports.filter(passport => {
    const matchesSearch = passport.passport_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         passport.order_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         passport.nomenclature?.name.toLowerCase().includes(searchTerm.toLowerCase())
    
    // Админы видят все паспорта, пользователи - только свои
    const matchesRole = isAdmin || passport.created_by === user?.id
    
    return matchesSearch && matchesRole
  })

  const handleArchive = async (id: number) => {
    if (window.confirm('Вы уверены, что хотите архивировать этот паспорт?')) {
      try {
        await archivePassport(id)
        toast.success('Паспорт успешно архивирован')
      } catch (error: any) {
        toast.error(error.message || 'Ошибка архивирования паспорта')
      }
    }
  }

  const handleExportPDF = async (id: number) => {
    try {
      await exportPassportPdf(id)
    } catch (error: any) {
      toast.error('Ошибка экспорта паспорта')
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="loading-spinner h-8 w-8"></div>
        <span className="ml-2 text-gray-600">Загрузка паспортов...</span>
      </div>
    )
  }

  if (error) {
    return (
      <div className="text-center py-12">
        <div className="mx-auto h-12 w-12 text-red-400">
          <ExclamationTriangleIcon />
        </div>
        <h3 className="mt-2 text-sm font-medium text-gray-900">Ошибка загрузки</h3>
        <p className="mt-1 text-sm text-gray-500">{error}</p>
        <div className="mt-6">
          <button
            onClick={() => refetchPassports()}
            className="btn btn-primary"
          >
            Попробовать снова
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Заголовок */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            {isAdmin ? 'Все паспорта' : 'Мои паспорта'}
          </h1>
          <p className="mt-1 text-sm text-gray-600">
            Управление активными паспортами ВЭД
          </p>
        </div>
        <Link href="/passports/create" className="btn btn-primary">
          <PlusIcon className="h-5 w-5 mr-2" />
          Создать паспорт
        </Link>
      </div>

      {/* Статистика */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="card">
          <div className="card-body">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="h-8 w-8 bg-blue-100 rounded-lg flex items-center justify-center">
                  <DocumentTextIcon className="h-5 w-5 text-blue-600" />
                </div>
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-500">Всего паспортов</p>
                <p className="text-2xl font-semibold text-gray-900">{passports.length}</p>
              </div>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="card-body">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="h-8 w-8 bg-green-100 rounded-lg flex items-center justify-center">
                  <CheckCircleIcon className="h-5 w-5 text-green-600" />
                </div>
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-500">Активных</p>
                <p className="text-2xl font-semibold text-gray-900">{passports.length}</p>
              </div>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="card-body">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="h-8 w-8 bg-orange-100 rounded-lg flex items-center justify-center">
                  <ArchiveBoxIcon className="h-5 w-5 text-orange-600" />
                </div>
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-500">В архиве</p>
                <p className="text-2xl font-semibold text-gray-900">0</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Поиск и фильтры */}
      <div className="card">
        <div className="card-body">
          <div className="flex items-center space-x-4">
            <div className="flex-1 relative">
              <MagnifyingGlassIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
              <input
                type="text"
                placeholder="Поиск по номеру паспорта, заказа или номенклатуре..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="form-input pl-10"
              />
            </div>
            <div className="flex items-center space-x-2">
              <span className="text-sm text-gray-500">
                Найдено: {filteredPassports.length}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Список паспортов */}
      {filteredPassports.length === 0 ? (
        <div className="text-center py-12">
          <DocumentTextIcon className="mx-auto h-12 w-12 text-gray-400" />
          <h3 className="mt-2 text-sm font-medium text-gray-900">
            {searchTerm ? 'Паспорты не найдены' : 'Паспорты не созданы'}
          </h3>
          <p className="mt-1 text-sm text-gray-500">
            {searchTerm 
              ? 'Попробуйте изменить поисковый запрос'
              : 'Начните с создания вашего первого паспорта'
            }
          </p>
          {!searchTerm && (
            <div className="mt-6">
              <Link href="/passports/create" className="btn btn-primary">
                <PlusIcon className="h-5 w-5 mr-2" />
                Создать первый паспорт
              </Link>
            </div>
          )}
        </div>
      ) : (
        <div className="card">
          <div className="card-header">
            <h2 className="text-lg font-semibold text-gray-900">Список паспортов</h2>
            <p className="text-sm text-gray-600">
              {isAdmin ? 'Все активные паспорта ВЭД' : 'Ваши активные паспорта ВЭД'}
            </p>
          </div>
          <div className="overflow-hidden">
            <div className="overflow-x-auto">
              <table className="table">
                <thead className="table-header">
                  <tr>
                    <th className="table-header-cell">Номер паспорта</th>
                    <th className="table-header-cell">Номер заказа</th>
                    <th className="table-header-cell">Номенклатура</th>
                    <th className="table-header-cell">Количество</th>
                    <th className="table-header-cell">Создан</th>
                    <th className="table-header-cell">Создатель</th>
                    <th className="table-header-cell text-right">Действия</th>
                  </tr>
                </thead>
                <tbody className="table-body">
                  {filteredPassports.map((passport) => (
                    <tr key={passport.id} className="table-row">
                      <td className="table-cell">
                        <div className="flex items-center">
                          <DocumentTextIcon className="h-5 w-5 text-gray-400 mr-2" />
                          <span className="font-medium text-gray-900">{passport.passport_number}</span>
                        </div>
                      </td>
                      <td className="table-cell">
                        <div className="flex items-center">
                          <TagIcon className="h-4 w-4 text-gray-400 mr-2" />
                          <span className="text-gray-900">{passport.order_number}</span>
                        </div>
                      </td>
                      <td className="table-cell">
                        <div className="max-w-xs">
                          <div className="text-sm font-medium text-gray-900 truncate">
                            {passport.nomenclature?.name}
                          </div>
                          <div className="text-xs text-gray-500 mt-1">
                            Код: {passport.nomenclature?.code_1c} | Артикул: {passport.nomenclature?.article}
                          </div>
                        </div>
                      </td>
                      <td className="table-cell">
                        <span className="badge badge-primary">{passport.quantity}</span>
                      </td>
                      <td className="table-cell">
                        <div className="flex items-center text-sm text-gray-500">
                          <CalendarIcon className="h-4 w-4 mr-1" />
                          {new Date(passport.created_at).toLocaleDateString('ru-RU', {
                            year: 'numeric',
                            month: '2-digit',
                            day: '2-digit',
                            hour: '2-digit',
                            minute: '2-digit'
                          })}
                        </div>
                      </td>
                      <td className="table-cell">
                        <div className="flex items-center text-sm text-gray-500">
                          <UserIcon className="h-4 w-4 mr-1" />
                          {passport.creator?.full_name || passport.creator?.username}
                        </div>
                      </td>
                      <td className="table-cell text-right">
                        <div className="flex items-center justify-end space-x-2">
                          <button
                            onClick={() => handleExportPDF(passport.id)}
                            className="p-2 text-gray-400 hover:text-blue-600 transition-colors duration-200"
                            title="Экспорт в PDF"
                          >
                            <ArrowDownTrayIcon className="h-4 w-4" />
                          </button>
                          <button
                            onClick={() => handleArchive(passport.id)}
                            className="p-2 text-gray-400 hover:text-orange-600 transition-colors duration-200"
                            title="Архивировать"
                          >
                            <ArchiveBoxIcon className="h-4 w-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

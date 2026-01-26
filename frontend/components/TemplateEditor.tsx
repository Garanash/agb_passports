import React, { useState, useEffect } from 'react'
import { templatesAPI } from '../lib/api'
import toast from 'react-hot-toast'
import {
  DocumentTextIcon,
  ArrowDownTrayIcon,
  ArrowUpTrayIcon,
  ClockIcon,
  CheckCircleIcon,
  XCircleIcon,
  ExclamationTriangleIcon,
} from '@heroicons/react/24/outline'

interface TemplateInfo {
  type: string
  filename: string
  size: number
  modified: string
  version?: number
}

interface TemplateVersion {
  version: number
  filename: string
  size: number
  created: string
  created_by: string
}

export default function TemplateEditor() {
  const [templates, setTemplates] = useState<TemplateInfo[]>([])
  const [selectedTemplate, setSelectedTemplate] = useState<string | null>(null)
  const [versions, setVersions] = useState<TemplateVersion[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [isUploading, setIsUploading] = useState(false)
  const [validationResult, setValidationResult] = useState<any>(null)

  useEffect(() => {
    loadTemplates()
  }, [])

  useEffect(() => {
    if (selectedTemplate) {
      loadVersions(selectedTemplate)
    }
  }, [selectedTemplate])

  const loadTemplates = async () => {
    try {
      setIsLoading(true)
      const data = await templatesAPI.getAll()
      setTemplates(data)
    } catch (error: any) {
      toast.error('Ошибка загрузки шаблонов: ' + (error.response?.data?.detail || error.message))
    } finally {
      setIsLoading(false)
    }
  }

  const loadVersions = async (templateType: string) => {
    try {
      const data = await templatesAPI.getVersions(templateType)
      setVersions(data)
    } catch (error: any) {
      console.error('Ошибка загрузки версий:', error)
    }
  }

  const handleDownload = async (templateType: string) => {
    try {
      setIsLoading(true)
      const blob = await templatesAPI.getTemplate(templateType)
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `${templateType}_template.docx`
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)
      toast.success('Шаблон скачан')
    } catch (error: any) {
      toast.error('Ошибка скачивания: ' + (error.response?.data?.detail || error.message))
    } finally {
      setIsLoading(false)
    }
  }

  const handleUpload = async (templateType: string, file: File) => {
    if (!file.name.endsWith('.docx')) {
      toast.error('Поддерживаются только файлы .docx')
      return
    }

    try {
      setIsUploading(true)
      
      // Валидация перед загрузкой
      try {
        const validation = await templatesAPI.validateTemplate(templateType, file)
        setValidationResult(validation)
        
        if (!validation.valid) {
          toast.error(`Шаблон не прошел валидацию. Отсутствуют плейсхолдеры: ${validation.missing_placeholders.join(', ')}`, {
            duration: 5000,
          })
          return
        }
      } catch (error) {
        console.error('Ошибка валидации:', error)
        // Продолжаем загрузку даже если валидация не удалась
      }

      await templatesAPI.uploadTemplate(templateType, file, true)
      toast.success('Шаблон успешно загружен')
      await loadTemplates()
      await loadVersions(templateType)
      setValidationResult(null)
    } catch (error: any) {
      toast.error('Ошибка загрузки: ' + (error.response?.data?.detail || error.message))
    } finally {
      setIsUploading(false)
    }
  }

  const handleRestore = async (templateType: string, version: number) => {
    if (!confirm(`Восстановить версию ${version}? Текущий шаблон будет сохранен как резервная копия.`)) {
      return
    }

    try {
      setIsLoading(true)
      await templatesAPI.restoreVersion(templateType, version)
      toast.success(`Шаблон восстановлен из версии ${version}`)
      await loadTemplates()
      await loadVersions(templateType)
    } catch (error: any) {
      toast.error('Ошибка восстановления: ' + (error.response?.data?.detail || error.message))
    } finally {
      setIsLoading(false)
    }
  }

  const formatFileSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' Б'
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' КБ'
    return (bytes / (1024 * 1024)).toFixed(2) + ' МБ'
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('ru-RU')
  }

  const templateLabels: Record<string, string> = {
    sticker: 'Шаблон наклеек',
    passport: 'Шаблон паспортов',
  }

  return (
    <div className="max-w-6xl mx-auto">
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Управление шаблонами</h2>

        {/* Список шаблонов */}
        <div className="space-y-4 mb-8">
          {isLoading && templates.length === 0 ? (
            <div className="text-center py-8 text-gray-500">Загрузка...</div>
          ) : templates.length === 0 ? (
            <div className="text-center py-8 text-gray-500">Шаблоны не найдены</div>
          ) : (
            templates.map((template) => (
              <div
                key={template.type}
                className={`border rounded-lg p-4 ${
                  selectedTemplate === template.type
                    ? 'border-blue-500 bg-blue-50'
                    : 'border-gray-200 hover:border-gray-300'
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-4">
                    <DocumentTextIcon className="h-8 w-8 text-blue-600" />
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900">
                        {templateLabels[template.type] || template.type}
                      </h3>
                      <p className="text-sm text-gray-500">
                        {template.filename} • {formatFileSize(template.size)} • Обновлен: {formatDate(template.modified)}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => handleDownload(template.type)}
                      className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                    >
                      <ArrowDownTrayIcon className="h-4 w-4 mr-2" />
                      Скачать
                    </button>
                    <label className="inline-flex items-center px-3 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 cursor-pointer">
                      <ArrowUpTrayIcon className="h-4 w-4 mr-2" />
                      Загрузить
                      <input
                        type="file"
                        accept=".docx"
                        className="hidden"
                        onChange={(e) => {
                          const file = e.target.files?.[0]
                          if (file) {
                            handleUpload(template.type, file)
                          }
                        }}
                        disabled={isUploading}
                      />
                    </label>
                    <button
                      onClick={() => setSelectedTemplate(selectedTemplate === template.type ? null : template.type)}
                      className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                    >
                      <ClockIcon className="h-4 w-4 mr-2" />
                      Версии
                    </button>
                  </div>
                </div>

                {/* Результат валидации */}
                {validationResult && selectedTemplate === template.type && (
                  <div className={`mt-4 p-3 rounded-md ${
                    validationResult.valid
                      ? 'bg-green-50 border border-green-200'
                      : 'bg-yellow-50 border border-yellow-200'
                  }`}>
                    <div className="flex items-start">
                      {validationResult.valid ? (
                        <CheckCircleIcon className="h-5 w-5 text-green-600 mt-0.5 mr-2" />
                      ) : (
                        <ExclamationTriangleIcon className="h-5 w-5 text-yellow-600 mt-0.5 mr-2" />
                      )}
                      <div className="flex-1">
                        <p className={`text-sm font-medium ${
                          validationResult.valid ? 'text-green-800' : 'text-yellow-800'
                        }`}>
                          {validationResult.valid
                            ? 'Шаблон валиден'
                            : 'Шаблон не прошел валидацию'}
                        </p>
                        {validationResult.missing_placeholders?.length > 0 && (
                          <p className="text-sm text-yellow-700 mt-1">
                            Отсутствуют плейсхолдеры: {validationResult.missing_placeholders.join(', ')}
                          </p>
                        )}
                        <p className="text-xs text-gray-600 mt-1">
                          Параграфов: {validationResult.paragraphs_count}, Таблиц: {validationResult.tables_count}
                        </p>
                      </div>
                    </div>
                  </div>
                )}

                {/* Список версий */}
                {selectedTemplate === template.type && versions.length > 0 && (
                  <div className="mt-4 border-t border-gray-200 pt-4">
                    <h4 className="text-sm font-semibold text-gray-700 mb-3">История версий:</h4>
                    <div className="space-y-2">
                      {versions.map((version) => (
                        <div
                          key={version.version}
                          className="flex items-center justify-between p-2 bg-gray-50 rounded-md"
                        >
                          <div className="flex items-center space-x-3">
                            <span className="text-sm font-medium text-gray-700">
                              Версия {version.version}
                            </span>
                            <span className="text-xs text-gray-500">
                              {formatFileSize(version.size)} • {formatDate(version.created)}
                            </span>
                          </div>
                          <button
                            onClick={() => handleRestore(template.type, version.version)}
                            className="text-sm text-blue-600 hover:text-blue-800"
                          >
                            Восстановить
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            ))
          )}
        </div>

        {/* Инструкция */}
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h3 className="text-sm font-semibold text-blue-900 mb-2">Инструкция по редактированию шаблонов:</h3>
          <ul className="text-sm text-blue-800 space-y-1 list-disc list-inside">
            <li>Скачайте текущий шаблон для редактирования</li>
            <li>Откройте файл в Microsoft Word или LibreOffice</li>
            <li>Используйте плейсхолдеры в формате {'{{ переменная }}'}</li>
            <li>Для наклеек доступны: logo, nomenclature_name, article, matrix, height, serial_number, production_date, website, date</li>
            <li>Загрузите отредактированный файл обратно</li>
            <li>Система автоматически создаст резервную копию перед заменой</li>
          </ul>
        </div>
      </div>
    </div>
  )
}

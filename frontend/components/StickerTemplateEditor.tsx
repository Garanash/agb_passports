import React, { useState, useEffect, useRef } from 'react'
import { templatesAPI } from '../lib/api'
import toast from 'react-hot-toast'
import mammoth from 'mammoth'
import {
  DocumentTextIcon,
  ArrowDownTrayIcon,
  ArrowUpTrayIcon,
  CheckIcon,
  PhotoIcon,
  TableCellsIcon,
  CodeBracketIcon,
  EyeIcon,
  PencilIcon,
  PlusIcon,
  PrinterIcon,
  DocumentDuplicateIcon,
  ClipboardDocumentIcon,
  ArrowUturnLeftIcon,
  ArrowUturnRightIcon,
  MagnifyingGlassIcon,
  ChatBubbleLeftRightIcon,
  Bars3Icon,
  Bars3BottomLeftIcon,
  Bars3BottomRightIcon,
  Bars4Icon,
  ListBulletIcon,
  BarsArrowUpIcon,
  BarsArrowDownIcon,
} from '@heroicons/react/24/outline'

interface Placeholder {
  name: string
  description: string
  type: 'text' | 'image' | 'barcode'
}

const AVAILABLE_PLACEHOLDERS: Placeholder[] = [
  { name: 'logo', description: 'Логотип компании', type: 'image' },
  { name: 'nomenclature_name', description: 'Название номенклатуры', type: 'text' },
  { name: 'article', description: 'Артикул', type: 'text' },
  { name: 'matrix', description: 'Типоразмер (NQ, HQ и т.д.)', type: 'text' },
  { name: 'height', description: 'Высота матрицы', type: 'text' },
  { name: 'waterways', description: 'Промывочные отверстия', type: 'text' },
  { name: 'serial_number', description: 'Серийный номер', type: 'text' },
  { name: 'serial number', description: 'Серийный номер (с пробелом)', type: 'text' },
  { name: 'stock_code', description: 'Штрихкод артикула', type: 'barcode' },
  { name: 'serial_number_code', description: 'Штрихкод серийного номера', type: 'barcode' },
  { name: 'production_date', description: 'Дата производства', type: 'text' },
  { name: 'date', description: 'Дата (краткая форма)', type: 'text' },
  { name: 'company_name_ru', description: 'Название компании (рус)', type: 'text' },
  { name: 'company_name_en', description: 'Название компании (англ)', type: 'text' },
  { name: 'website', description: 'Сайт компании', type: 'text' },
  { name: 'tool size', description: 'Размер инструмента', type: 'text' },
]

export default function StickerTemplateEditor() {
  const [templateContent, setTemplateContent] = useState<string>('')
  const [htmlContent, setHtmlContent] = useState<string>('')
  const [templateFile, setTemplateFile] = useState<File | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [isSaving, setIsSaving] = useState(false)
  const [previewMode, setPreviewMode] = useState<'edit' | 'preview'>('edit')
  const [selectedPlaceholder, setSelectedPlaceholder] = useState<Placeholder | null>(null)
  const [activeTab, setActiveTab] = useState<'home' | 'insert' | 'layout'>('home')
  const [fontFamily, setFontFamily] = useState('Arial')
  const [fontSize, setFontSize] = useState('11')
  const [isBold, setIsBold] = useState(false)
  const [isItalic, setIsItalic] = useState(false)
  const [isUnderline, setIsUnderline] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const logoInputRef = useRef<HTMLInputElement>(null)
  const editorRef = useRef<HTMLDivElement>(null)

  const autoSaveRef = useRef<NodeJS.Timeout | null>(null)
  const isAutoSavingRef = useRef(false)

  useEffect(() => {
    // Автоматически загружаем шаблон при входе
    loadTemplate()
    
    // Автоматически сохраняем при выходе
    return () => {
      if (htmlContent && editorRef.current && !isAutoSavingRef.current) {
        handleAutoSave()
      }
    }
  }, [])

  // Автосохранение при изменении содержимого (с задержкой)
  useEffect(() => {
    if (htmlContent && editorRef.current && !isLoading) {
      // Очищаем предыдущий таймер
      if (autoSaveRef.current) {
        clearTimeout(autoSaveRef.current)
      }
      
      // Устанавливаем новый таймер
      autoSaveRef.current = setTimeout(() => {
        if (!isAutoSavingRef.current) {
          handleAutoSave()
        }
      }, 3000) // Сохраняем через 3 секунды после последнего изменения
      
      return () => {
        if (autoSaveRef.current) {
          clearTimeout(autoSaveRef.current)
        }
      }
    }
  }, [htmlContent, isLoading])

  const handleAutoSave = async () => {
    if (!editorRef.current || !htmlContent || isAutoSavingRef.current) {
      return
    }

    try {
      isAutoSavingRef.current = true
      // Получаем HTML из редактора
      const html = editorRef.current.innerHTML
      
      // Сохраняем через API
      await templatesAPI.saveFromHtml('sticker', html)
      console.log('✅ Автосохранение выполнено')
    } catch (error: any) {
      console.error('Ошибка автосохранения:', error)
    } finally {
      isAutoSavingRef.current = false
    }
  }

  const loadTemplate = async () => {
    try {
      setIsLoading(true)
      const blob = await templatesAPI.getTemplate('sticker')
      
      // Конвертируем DOCX в HTML для редактирования
      const arrayBuffer = await blob.arrayBuffer()
      const result = await mammoth.convertToHtml({ arrayBuffer })
      setHtmlContent(result.value)
      setTemplateContent(result.value)
      
      // Сохраняем файл для последующего сохранения
      const file = new File([blob], 'sticker_template.docx', { type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' })
      setTemplateFile(file)
      
      // Не показываем toast при автоматической загрузке
      if (htmlContent === '') {
        toast.success('Шаблон загружен и готов к редактированию', { duration: 2000 })
      }
    } catch (error: any) {
      toast.error('Ошибка загрузки шаблона: ' + (error.response?.data?.detail || error.message))
    } finally {
      setIsLoading(false)
    }
  }

  const handleSave = async () => {
    if (!editorRef.current || !htmlContent) {
      toast.error('Нет содержимого для сохранения')
      return
    }

    try {
      setIsSaving(true)
      toast.loading('Сохранение шаблона...')
      
      // Получаем HTML из редактора
      const html = editorRef.current.innerHTML
      
      // Сохраняем через API
      await templatesAPI.saveFromHtml('sticker', html)
      toast.success('Шаблон успешно сохранен')
      
    } catch (error: any) {
      toast.error('Ошибка сохранения: ' + (error.response?.data?.detail || error.message))
    } finally {
      setIsSaving(false)
      toast.dismiss()
    }
  }

  const handleDownload = async () => {
    try {
      setIsLoading(true)
      const blob = await templatesAPI.getTemplate('sticker')
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = 'sticker_template.docx'
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

  const handleUpload = async (file: File) => {
    if (!file.name.endsWith('.docx')) {
      toast.error('Поддерживаются только файлы .docx')
      return
    }

    try {
      setIsSaving(true)
      
      // Валидация
      try {
        const validation = await templatesAPI.validateTemplate('sticker', file)
        if (!validation.valid) {
          toast.error(`Шаблон не прошел валидацию. Отсутствуют: ${validation.missing_placeholders.join(', ')}`, {
            duration: 5000,
          })
          return
        }
      } catch (error) {
        console.error('Ошибка валидации:', error)
      }

      await templatesAPI.uploadTemplate('sticker', file, true)
      toast.success('Шаблон успешно загружен')
      await loadTemplate()
    } catch (error: any) {
      toast.error('Ошибка загрузки: ' + (error.response?.data?.detail || error.message))
    } finally {
      setIsSaving(false)
    }
  }

  const insertPlaceholder = (placeholder: Placeholder) => {
    const placeholderText = `{{${placeholder.name}}}`
    
    // Если есть активный редактор, вставляем туда
    if (editorRef.current) {
      editorRef.current.focus()
      const selection = window.getSelection()
      
      if (selection && selection.rangeCount > 0) {
        const range = selection.getRangeAt(0)
        range.deleteContents()
        
        // Создаем span с особым стилем для плейсхолдера
        const span = document.createElement('span')
        span.textContent = placeholderText
        span.style.backgroundColor = '#fef3c7'
        span.style.color = '#92400e'
        span.style.padding = '2px 4px'
        span.style.borderRadius = '3px'
        span.style.fontFamily = 'monospace'
        span.style.fontWeight = 'bold'
        span.contentEditable = 'false'
        
        range.insertNode(span)
        
        // Устанавливаем курсор после вставленного элемента
        range.setStartAfter(span)
        range.setEndAfter(span)
        selection.removeAllRanges()
        selection.addRange(range)
        
        // Обновляем HTML контент
        if (editorRef.current) {
          setHtmlContent(editorRef.current.innerHTML)
        }
      } else {
        // Если нет выделения, вставляем в конец
        const span = document.createElement('span')
        span.textContent = placeholderText
        span.style.backgroundColor = '#fef3c7'
        span.style.color = '#92400e'
        span.style.padding = '2px 4px'
        span.style.borderRadius = '3px'
        span.style.fontFamily = 'monospace'
        span.style.fontWeight = 'bold'
        editorRef.current.appendChild(span)
        setHtmlContent(editorRef.current.innerHTML)
      }
    }
    
    toast.success(`Вставлен плейсхолдер: ${placeholderText}`, { duration: 2000 })
  }

  const applyFormat = (command: string, value?: string) => {
    editorRef.current?.focus()
    document.execCommand(command, false, value)
    updateFormatState()
  }

  const updateFormatState = () => {
    setIsBold(document.queryCommandState('bold'))
    setIsItalic(document.queryCommandState('italic'))
    setIsUnderline(document.queryCommandState('underline'))
  }

  useEffect(() => {
    if (editorRef.current) {
      editorRef.current.addEventListener('mouseup', updateFormatState)
      editorRef.current.addEventListener('keyup', updateFormatState)
      return () => {
        editorRef.current?.removeEventListener('mouseup', updateFormatState)
        editorRef.current?.removeEventListener('keyup', updateFormatState)
      }
    }
  }, [htmlContent])

  return (
    <div className="flex flex-col bg-gray-100 w-full" style={{ minHeight: 'calc(100vh - 200px)' }}>
      {/* Панель инструментов с кнопками сохранения/загрузки */}
      <div className="bg-white border-b border-gray-200 px-4 py-2 flex items-center justify-between flex-shrink-0">
        <div className="flex items-center space-x-2">
          <button
            onClick={handleDownload}
            disabled={isLoading}
            className="flex items-center px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-100 rounded-md disabled:opacity-50"
            title="Скачать шаблон"
          >
            <ArrowDownTrayIcon className="h-4 w-4 mr-2" />
            Скачать
          </button>
          <button
            onClick={handleSave}
            disabled={isSaving || !htmlContent}
            className="flex items-center px-3 py-1.5 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-md disabled:opacity-50"
            title="Сохранить изменения"
          >
            <CheckIcon className="h-4 w-4 mr-2" />
            Сохранить
          </button>
          <label className="flex items-center px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-100 rounded-md cursor-pointer" title="Загрузить файл">
            <ArrowUpTrayIcon className="h-4 w-4 mr-2" />
            Загрузить
            <input
              ref={fileInputRef}
              type="file"
              accept=".docx"
              className="hidden"
              onChange={(e) => {
                const file = e.target.files?.[0]
                if (file) {
                  handleUpload(file)
                }
              }}
              disabled={isSaving}
            />
          </label>
        </div>
        {isSaving && (
          <span className="text-sm text-gray-500">Сохранение...</span>
        )}
      </div>

      {/* Вкладки меню */}
      <div className="bg-white border-b border-gray-300 flex items-center">
        <button
          onClick={() => setActiveTab('home')}
          className={`px-4 py-2 text-sm font-medium border-b-2 ${
            activeTab === 'home'
              ? 'border-blue-600 text-blue-600'
              : 'border-transparent text-gray-600 hover:text-gray-900'
          }`}
        >
          Главная
        </button>
        <button
          onClick={() => setActiveTab('insert')}
          className={`px-4 py-2 text-sm font-medium border-b-2 ${
            activeTab === 'insert'
              ? 'border-blue-600 text-blue-600'
              : 'border-transparent text-gray-600 hover:text-gray-900'
          }`}
        >
          Вставка
        </button>
        <button
          onClick={() => setActiveTab('layout')}
          className={`px-4 py-2 text-sm font-medium border-b-2 ${
            activeTab === 'layout'
              ? 'border-blue-600 text-blue-600'
              : 'border-transparent text-gray-600 hover:text-gray-900'
          }`}
        >
          Макет
        </button>
      </div>

      {/* Лента инструментов (Ribbon) */}
      <div className="bg-gray-100 border-b border-gray-300 px-4 py-3">
        {activeTab === 'home' && (
          <div className="flex items-center space-x-4 flex-wrap">
            {/* Файловые операции */}
            <div className="flex items-center space-x-1 border-r border-gray-300 pr-4">
              <button
                onClick={() => window.print()}
                className="p-2 hover:bg-gray-200 rounded"
                title="Печать"
              >
                <PrinterIcon className="h-5 w-5 text-gray-700" />
              </button>
              <button
                onClick={() => applyFormat('cut')}
                className="p-2 hover:bg-gray-200 rounded"
                title="Вырезать"
              >
                <DocumentDuplicateIcon className="h-5 w-5 text-gray-700" />
              </button>
              <button
                onClick={() => applyFormat('copy')}
                className="p-2 hover:bg-gray-200 rounded"
                title="Копировать"
              >
                <ClipboardDocumentIcon className="h-5 w-5 text-gray-700" />
              </button>
              <button
                onClick={() => applyFormat('paste')}
                className="p-2 hover:bg-gray-200 rounded"
                title="Вставить"
              >
                <ClipboardDocumentIcon className="h-5 w-5 text-gray-700" />
              </button>
              <button
                onClick={() => applyFormat('undo')}
                className="p-2 hover:bg-gray-200 rounded"
                title="Отменить"
              >
                <ArrowUturnLeftIcon className="h-5 w-5 text-gray-700" />
              </button>
              <button
                onClick={() => applyFormat('redo')}
                className="p-2 hover:bg-gray-200 rounded"
                title="Повторить"
              >
                <ArrowUturnRightIcon className="h-5 w-5 text-gray-700" />
              </button>
            </div>

            {/* Шрифт */}
            <div className="flex items-center space-x-2 border-r border-gray-300 pr-4">
              <select
                value={fontFamily}
                onChange={(e) => {
                  setFontFamily(e.target.value)
                  applyFormat('fontName', e.target.value)
                }}
                className="border border-gray-300 rounded px-2 py-1 text-sm"
              >
                <option value="Arial">Arial</option>
                <option value="Times New Roman">Times New Roman</option>
                <option value="Calibri">Calibri</option>
                <option value="Verdana">Verdana</option>
              </select>
              <select
                value={fontSize}
                onChange={(e) => {
                  setFontSize(e.target.value)
                  applyFormat('fontSize', e.target.value)
                }}
                className="border border-gray-300 rounded px-2 py-1 text-sm w-16"
              >
                {[8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 72].map(size => (
                  <option key={size} value={size.toString()}>{size}</option>
                ))}
              </select>
            </div>

            {/* Форматирование текста */}
            <div className="flex items-center space-x-1 border-r border-gray-300 pr-4">
              <button
                onClick={() => applyFormat('bold')}
                className={`p-2 rounded ${isBold ? 'bg-blue-200' : 'hover:bg-gray-200'}`}
                title="Жирный (Ctrl+B)"
              >
                <span className="font-bold text-gray-700">B</span>
              </button>
              <button
                onClick={() => applyFormat('italic')}
                className={`p-2 rounded ${isItalic ? 'bg-blue-200' : 'hover:bg-gray-200'}`}
                title="Курсив (Ctrl+I)"
              >
                <span className="italic text-gray-700">I</span>
              </button>
              <button
                onClick={() => applyFormat('underline')}
                className={`p-2 rounded ${isUnderline ? 'bg-blue-200' : 'hover:bg-gray-200'}`}
                title="Подчеркнутый (Ctrl+U)"
              >
                <span className="underline text-gray-700">U</span>
              </button>
              <button
                onClick={() => applyFormat('strikeThrough')}
                className="p-2 rounded hover:bg-gray-200"
                title="Зачеркнутый"
              >
                <span className="line-through text-gray-700">S</span>
              </button>
            </div>

            {/* Выравнивание */}
            <div className="flex items-center space-x-1 border-r border-gray-300 pr-4">
              <button
                onClick={() => applyFormat('justifyLeft')}
                className="p-2 rounded hover:bg-gray-200"
                title="По левому краю"
              >
                <Bars3BottomLeftIcon className="h-5 w-5 text-gray-700" />
              </button>
              <button
                onClick={() => applyFormat('justifyCenter')}
                className="p-2 rounded hover:bg-gray-200"
                title="По центру"
              >
                <Bars3Icon className="h-5 w-5 text-gray-700" />
              </button>
              <button
                onClick={() => applyFormat('justifyRight')}
                className="p-2 rounded hover:bg-gray-200"
                title="По правому краю"
              >
                <Bars3BottomRightIcon className="h-5 w-5 text-gray-700" />
              </button>
              <button
                onClick={() => applyFormat('justifyFull')}
                className="p-2 rounded hover:bg-gray-200 bg-blue-200"
                title="По ширине"
              >
                <Bars4Icon className="h-5 w-5 text-gray-700" />
              </button>
            </div>

            {/* Списки */}
            <div className="flex items-center space-x-1">
              <button
                onClick={() => applyFormat('insertUnorderedList')}
                className="p-2 rounded hover:bg-gray-200"
                title="Маркированный список"
              >
                <ListBulletIcon className="h-5 w-5 text-gray-700" />
              </button>
              <button
                onClick={() => applyFormat('insertOrderedList')}
                className="p-2 rounded hover:bg-gray-200"
                title="Нумерованный список"
              >
                <BarsArrowUpIcon className="h-5 w-5 text-gray-700" />
              </button>
              <button
                onClick={() => applyFormat('outdent')}
                className="p-2 rounded hover:bg-gray-200"
                title="Уменьшить отступ"
              >
                <BarsArrowDownIcon className="h-5 w-5 text-gray-700" />
              </button>
              <button
                onClick={() => applyFormat('indent')}
                className="p-2 rounded hover:bg-gray-200"
                title="Увеличить отступ"
              >
                <BarsArrowUpIcon className="h-5 w-5 text-gray-700" />
              </button>
            </div>
          </div>
        )}

        {activeTab === 'insert' && (
          <div className="flex items-center space-x-4">
            <div className="text-sm text-gray-600">Вставка элементов</div>
            <label className="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 cursor-pointer">
              <ArrowUpTrayIcon className="h-4 w-4 mr-2" />
              Загрузить файл
              <input
                ref={fileInputRef}
                type="file"
                accept=".docx"
                className="hidden"
                onChange={(e) => {
                  const file = e.target.files?.[0]
                  if (file) {
                    handleUpload(file)
                  }
                }}
                disabled={isSaving}
              />
            </label>
            <label className="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-green-600 border border-transparent rounded-md hover:bg-green-700 cursor-pointer">
              <PhotoIcon className="h-4 w-4 mr-2" />
              Загрузить логотип
              <input
                type="file"
                accept="image/png,image/jpeg,image/jpg"
                className="hidden"
                onChange={async (e) => {
                  const file = e.target.files?.[0]
                  if (file) {
                    try {
                      setIsLoading(true)
                      await templatesAPI.logo.upload(file)
                      toast.success('Логотип успешно загружен')
                    } catch (error: any) {
                      toast.error('Ошибка загрузки логотипа: ' + (error.response?.data?.detail || error.message))
                    } finally {
                      setIsLoading(false)
                    }
                  }
                }}
                disabled={isLoading}
              />
            </label>
          </div>
        )}

        {activeTab === 'layout' && (
          <div className="flex items-center space-x-4">
            <div className="text-sm text-gray-600">Настройки макета</div>
          </div>
        )}
      </div>

      {/* Основная область */}
      <div className="flex-1 flex overflow-hidden" style={{ height: 'calc(100vh - 200px)' }}>
        {/* Боковая панель с переменными */}
        <div className="w-64 border-r border-gray-300 bg-gray-50 overflow-y-auto">
          <div className="p-4">
            <h3 className="text-sm font-semibold text-gray-900 mb-3 flex items-center">
              <CodeBracketIcon className="h-4 w-4 mr-2" />
              Переменные
            </h3>
            
            <div className="space-y-2">
              {AVAILABLE_PLACEHOLDERS.map((placeholder) => (
                <button
                  key={placeholder.name}
                  onClick={() => {
                    setSelectedPlaceholder(placeholder)
                    insertPlaceholder(placeholder)
                  }}
                  className={`w-full text-left p-2 rounded border transition-colors text-xs ${
                    selectedPlaceholder?.name === placeholder.name
                      ? 'border-blue-500 bg-blue-50'
                      : 'border-gray-200 bg-white hover:border-gray-300'
                  }`}
                >
                  <div className="flex items-center space-x-2">
                    {placeholder.type === 'image' && (
                      <PhotoIcon className="h-3 w-3 text-purple-500" />
                    )}
                    {placeholder.type === 'barcode' && (
                      <TableCellsIcon className="h-3 w-3 text-green-500" />
                    )}
                    <code className="text-xs font-mono text-blue-600">
                      {`{{${placeholder.name}}}`}
                    </code>
                  </div>
                  <p className="text-xs text-gray-600 mt-1">
                    {placeholder.description}
                  </p>
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Область документа */}
        <div className="flex-1 flex flex-col bg-gray-200">
          {/* Линейки и область документа */}
          <div className="flex-1 overflow-auto relative">
            {/* Вертикальная линейка */}
            <div className="absolute left-0 top-0 bottom-0 w-8 bg-gray-300 border-r border-gray-400">
              <div className="text-xs text-gray-600 text-center py-1">1</div>
              <div className="text-xs text-gray-600 text-center py-1">2</div>
            </div>

            {/* Горизонтальная линейка */}
            <div className="absolute top-0 left-8 right-0 h-6 bg-gray-300 border-b border-gray-400 flex items-center px-2">
              <div className="flex space-x-4 text-xs text-gray-600">
                <span>1</span>
                <span>2</span>
                <span>3</span>
                <span>4</span>
                <span>5</span>
                <span>6</span>
              </div>
            </div>

            {/* Область документа */}
            <div className="ml-8 mt-6 p-8">
              <div className="bg-white shadow-lg mx-auto" style={{ width: '210mm', minHeight: '297mm', padding: '20mm' }}>
                {htmlContent ? (
                  <div
                    ref={editorRef}
                    contentEditable
                    className="outline-none min-h-full"
                    style={{
                      fontFamily: fontFamily,
                      fontSize: `${fontSize}pt`,
                      lineHeight: '1.5',
                      color: '#000000',
                    }}
                    dangerouslySetInnerHTML={{ __html: htmlContent }}
                    suppressContentEditableWarning
                    onInput={(e) => {
                      if (editorRef.current) {
                        setHtmlContent(editorRef.current.innerHTML)
                        updateFormatState()
                      }
                    }}
                    onMouseUp={updateFormatState}
                    onKeyUp={updateFormatState}
                  />
                ) : (
                  <div className="text-center py-32">
                    <DocumentTextIcon className="h-16 w-16 text-gray-400 mx-auto mb-4" />
                    <p className="text-gray-500 mb-4 text-lg">Загрузите шаблон для редактирования</p>
                    <button
                      onClick={loadTemplate}
                      disabled={isLoading}
                      className="inline-flex items-center px-6 py-3 text-base font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50"
                    >
                      <ArrowDownTrayIcon className="h-5 w-5 mr-2" />
                      {isLoading ? 'Загрузка...' : 'Загрузить шаблон'}
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Правая боковая панель */}
        <div className="w-12 bg-gray-100 border-l border-gray-300 flex flex-col items-center py-2 space-y-4">
          <button className="p-2 hover:bg-gray-200 rounded" title="Масштаб">
            <MagnifyingGlassIcon className="h-5 w-5 text-gray-600" />
          </button>
          <button className="p-2 hover:bg-gray-200 rounded" title="Комментарии">
            <ChatBubbleLeftRightIcon className="h-5 w-5 text-gray-600" />
          </button>
          <button className="p-2 hover:bg-gray-200 rounded" title="Параметры страницы">
            <Bars3Icon className="h-5 w-5 text-gray-600" />
          </button>
        </div>
        
        {/* Кнопка загрузки логотипа - в тулбаре */}
        <input
          type="file"
          accept="image/png,image/jpeg,image/jpg"
          ref={fileInputRef}
          className="hidden"
          onChange={async (e) => {
            const file = e.target.files?.[0]
            if (file) {
              try {
                setIsLoading(true)
                await templatesAPI.logo.upload(file)
                toast.success('Логотип успешно загружен')
              } catch (error: any) {
                toast.error('Ошибка загрузки логотипа: ' + (error.response?.data?.detail || error.message))
              } finally {
                setIsLoading(false)
                if (fileInputRef.current) {
                  fileInputRef.current.value = ''
                }
              }
            }
          }}
        />
      </div>

    </div>
  )
}

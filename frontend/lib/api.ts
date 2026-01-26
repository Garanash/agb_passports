/**
 * API клиент для взаимодействия с backend
 */

// Определяем базовый URL API
const getApiUrl = (): string => {
  // В браузере используем относительный путь через nginx
  if (typeof window !== 'undefined') {
    return '/api'
  }
  // На сервере (SSR) используем переменную окружения или дефолт
  return process.env.NEXT_PUBLIC_API_URL || 'http://backend:8000/api'
}

const API_BASE_URL = getApiUrl()

// Вспомогательная функция для получения токена
const getToken = (): string | null => {
  if (typeof window === 'undefined') return null
  return localStorage.getItem('token')
}

// Вспомогательная функция для выполнения запросов
const fetchAPI = async (
  endpoint: string,
  options: RequestInit = {}
): Promise<Response> => {
  const token = getToken()
  const url = `${API_BASE_URL}${endpoint}`
  
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    ...options.headers,
  }
  
  if (token) {
    headers['Authorization'] = `Bearer ${token}`
  }
  
  const response = await fetch(url, {
    ...options,
    headers,
  })
  
  if (!response.ok) {
    // Обработка 401 - неавторизован
    if (response.status === 401) {
      if (typeof window !== 'undefined') {
        localStorage.removeItem('token')
        localStorage.removeItem('user')
        // Не делаем редирект здесь, чтобы компоненты могли обработать ошибку
      }
    }
    const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
    throw { response: { data: error, status: response.status } }
  }
  
  return response
}

// API для аутентификации
export const authAPI = {
  login: async (username: string, password: string) => {
    const response = await fetchAPI('/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    })
    return response.json()
  },
  
  logout: () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('token')
      localStorage.removeItem('user')
    }
  },
  
  getCurrentUser: async () => {
    const response = await fetchAPI('/v1/auth/me')
    return response.json()
  },
}

// API для паспортов
export const passportsAPI = {
  getAll: async (page: number = 1, pageSize: number = 20) => {
    const response = await fetchAPI(`/v1/passports/?page=${page}&page_size=${pageSize}`)
    return response.json()
  },
  
  getById: async (id: number) => {
    const response = await fetchAPI(`/v1/passports/${id}`)
    return response.json()
  },
  
  create: async (passportData: any) => {
    const response = await fetchAPI('/v1/passports/', {
      method: 'POST',
      body: JSON.stringify(passportData),
    })
    return response.json()
  },
  
  createBulk: async (bulkData: any) => {
    const response = await fetchAPI('/v1/passports/bulk', {
      method: 'POST',
      body: JSON.stringify(bulkData),
    })
    return response.json()
  },
  
  archive: async (id: number) => {
    const response = await fetchAPI(`/v1/passports/${id}/archive`, {
      method: 'POST',
    })
    return response.json()
  },
  
  activate: async (id: number) => {
    const response = await fetchAPI(`/v1/passports/${id}/activate`, {
      method: 'POST',
    })
    return response.json()
  },
  
  exportPdf: async (id: number): Promise<Blob> => {
    const token = getToken()
    const url = `${API_BASE_URL}/v1/passports/${id}/export/pdf`
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    })
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
      throw { response: { data: error, status: response.status } }
    }
    
    return response.blob()
  },
  
  exportBulkPdf: async (passportIds: number[]): Promise<Blob> => {
    const token = getToken()
    const url = `${API_BASE_URL}/v1/passports/export/bulk/pdf`
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify(passportIds),
    })
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
      throw { response: { data: error, status: response.status } }
    }
    
    return response.blob()
  },
  
  exportExcel: async (): Promise<Blob> => {
    const token = getToken()
    const url = `${API_BASE_URL}/v1/passports/export/excel`
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    })
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
      throw { response: { data: error, status: response.status } }
    }
    
    return response.blob()
  },
  
  exportSelectedExcel: async (passportIds: number[]): Promise<Blob> => {
    const token = getToken()
    const url = `${API_BASE_URL}/v1/passports/export/excel/selected`
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify(passportIds),
    })
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
      throw { response: { data: error, status: response.status } }
    }
    
    return response.blob()
  },
  
  exportStickersDocx: async (passportIds: number[]): Promise<Blob> => {
    const token = getToken()
    const url = `${API_BASE_URL}/v1/passports/export/stickers/docx`
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify(passportIds),
    })
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
      throw { response: { data: error, status: response.status } }
    }
    
    return response.blob()
  },
  
  exportStickersPdf: async (passportIds: number[]): Promise<Blob> => {
    const token = getToken()
    const url = `${API_BASE_URL}/v1/passports/export/stickers/pdf`
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify(passportIds),
    })
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
      throw { response: { data: error, status: response.status } }
    }
    
    return response.blob()
  },
}

// API для номенклатуры
export const nomenclatureAPI = {
  getAll: async () => {
    const response = await fetchAPI('/v1/nomenclature/')
    return response.json()
  },
  
  getById: async (id: number) => {
    const response = await fetchAPI(`/v1/nomenclature/${id}`)
    return response.json()
  },
  
  create: async (nomenclatureData: any) => {
    const response = await fetchAPI('/v1/nomenclature/', {
      method: 'POST',
      body: JSON.stringify(nomenclatureData),
    })
    return response.json()
  },
  
  update: async (id: number, nomenclatureData: any) => {
    const response = await fetchAPI(`/v1/nomenclature/${id}`, {
      method: 'PUT',
      body: JSON.stringify(nomenclatureData),
    })
    return response.json()
  },
  
  delete: async (id: number) => {
    const response = await fetchAPI(`/v1/nomenclature/${id}`, {
      method: 'DELETE',
    })
    return response.json()
  },
}

// API для пользователей
export const usersAPI = {
  getAll: async () => {
    const response = await fetchAPI('/v1/users/')
    return response.json()
  },
  
  getById: async (id: number) => {
    const response = await fetchAPI(`/v1/users/${id}`)
    return response.json()
  },
  
  create: async (userData: any) => {
    const response = await fetchAPI('/v1/users/', {
      method: 'POST',
      body: JSON.stringify(userData),
    })
    return response.json()
  },
  
  update: async (id: number, userData: any) => {
    const response = await fetchAPI(`/v1/users/${id}`, {
      method: 'PUT',
      body: JSON.stringify(userData),
    })
    return response.json()
  },
  
  delete: async (id: number) => {
    const response = await fetchAPI(`/v1/users/${id}`, {
      method: 'DELETE',
    })
    return response.json()
  },
}

// API для шаблонов
export const templatesAPI = {
  getAll: async () => {
    const response = await fetchAPI('/v1/templates/')
    return response.json()
  },
  
  getVersions: async (templateType: string) => {
    const response = await fetchAPI(`/v1/templates/${templateType}/versions`)
    return response.json()
  },
  
  getTemplate: async (templateType: string): Promise<Blob> => {
    const token = getToken()
    const url = `${API_BASE_URL}/v1/templates/${templateType}`
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    })
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
      throw { response: { data: error, status: response.status } }
    }
    
    return response.blob()
  },
  
  uploadTemplate: async (templateType: string, file: File, createBackup: boolean = true) => {
    const token = getToken()
    const url = `${API_BASE_URL}/v1/templates/${templateType}/upload`
    const formData = new FormData()
    formData.append('file', file)
    formData.append('create_backup', createBackup.toString())
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
      },
      body: formData,
    })
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
      throw { response: { data: error, status: response.status } }
    }
    
    return response.json()
  },
  
  validateTemplate: async (templateType: string, file: File) => {
    const token = getToken()
    const url = `${API_BASE_URL}/v1/templates/${templateType}/validate`
    const formData = new FormData()
    formData.append('file', file)
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
      },
      body: formData,
    })
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
      throw { response: { data: error, status: response.status } }
    }
    
    return response.json()
  },
  
  restoreVersion: async (templateType: string, version: number) => {
    const response = await fetchAPI(`/v1/templates/${templateType}/restore/${version}`, {
      method: 'POST',
    })
    return response.json()
  },
  
  saveFromHtml: async (templateType: string, htmlContent: string) => {
    const token = getToken()
    const url = `${API_BASE_URL}/v1/templates/${templateType}/save-from-html`
    const formData = new FormData()
    formData.append('html_content', htmlContent)
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
      },
      body: formData,
    })
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
      throw { response: { data: error, status: response.status } }
    }
    
    return response.json()
  },

  logo: {
    upload: async (file: File) => {
      const token = getToken()
      const url = `${API_BASE_URL}/v1/templates/logo/upload`
      const formData = new FormData()
      formData.append('file', file)
      
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
        },
        body: formData,
      })
      
      if (!response.ok) {
        const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
        throw { response: { data: error, status: response.status } }
      }
      
      return response.json()
    },

    get: async (): Promise<Blob> => {
      const token = getToken()
      const url = `${API_BASE_URL}/v1/templates/logo`
      
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      })
      
      if (!response.ok) {
        const error = await response.json().catch(() => ({ detail: 'Unknown error' }))
        throw { response: { data: error, status: response.status } }
      }
      
      return response.blob()
    },
  },
}

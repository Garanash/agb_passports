import axios from 'axios'

// Типы для глобальной конфигурации
declare global {
  interface Window {
    API_CONFIG?: {
      API_URL: string
    }
  }
}

// Функция для получения базового URL API
function getApiBaseUrl(): string {
  if (typeof window === 'undefined') {
    return process.env.NEXT_PUBLIC_API_URL || ''
  }
  
  // Проверяем глобальную конфигурацию из config.js
  if (window.API_CONFIG?.API_URL !== undefined) {
    return window.API_CONFIG.API_URL
  }
  
  // Используем переменную окружения или пустую строку для относительных путей
  return process.env.NEXT_PUBLIC_API_URL || ''
}

const APP_NAME = process.env.NEXT_PUBLIC_APP_NAME || 'AGB Passports'
const APP_VERSION = process.env.NEXT_PUBLIC_APP_VERSION || '1.0.0'

// Определяем окружение
const isProduction = process.env.NODE_ENV === 'production'

// Создаем экземпляр axios с базовой конфигурацией
// Используем пустую строку для относительных путей через nginx
const api = axios.create({
  baseURL: getApiBaseUrl(),
  headers: {
    'Content-Type': 'application/json',
    'X-App-Name': APP_NAME,
    'X-App-Version': APP_VERSION,
  },
  timeout: 30000, // 30 секунд таймаут
})

// Обновляем baseURL при изменении конфигурации
if (typeof window !== 'undefined') {
  // Ждем загрузки config.js и обновляем baseURL
  window.addEventListener('load', () => {
    const newBaseUrl = getApiBaseUrl()
    if (newBaseUrl !== api.defaults.baseURL) {
      api.defaults.baseURL = newBaseUrl
    }
  })
}

// Интерцептор для добавления токена авторизации
api.interceptors.request.use(
  (config) => {
    if (typeof window !== 'undefined') {
      const token = localStorage.getItem('token')
      if (token) {
        config.headers.Authorization = `Bearer ${token}`
      }
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// Интерцептор для обработки ошибок авторизации
api.interceptors.response.use(
  (response) => response,
  (error) => {
    // Логируем ошибки для отладки
    if (error.response) {
      console.error('API Error:', {
        status: error.response.status,
        statusText: error.response.statusText,
        url: error.config?.url,
        data: error.response.data
      })
    } else if (error.request) {
      console.error('Network Error:', error.message)
    } else {
      console.error('Error:', error.message)
    }
    
    if (error.response?.status === 401) {
      if (typeof window !== 'undefined') {
        localStorage.removeItem('token')
        localStorage.removeItem('user')
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  }
)

// API методы для авторизации
export const authAPI = {
  login: async (username: string, password: string) => {
    const response = await api.post('/api/v1/auth/login', {
      username,
      password,
    })
    return response.data
  },

  getCurrentUser: async () => {
    const response = await api.get('/api/v1/auth/me')
    return response.data
  },

  logout: () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('token')
      localStorage.removeItem('user')
    }
  },
}

// API методы для номенклатуры
export const nomenclatureAPI = {
  getAll: async () => {
    const response = await api.get('/api/v1/nomenclature/')
    return response.data
  },

  getById: async (id: number) => {
    const response = await api.get(`/api/v1/nomenclature/${id}`)
    return response.data
  },

  create: async (data: any) => {
    const response = await api.post('/api/v1/nomenclature/', data)
    return response.data
  },

  update: async (id: number, data: any) => {
    const response = await api.put(`/api/v1/nomenclature/${id}`, data)
    return response.data
  },

  delete: async (id: number) => {
    const response = await api.delete(`/api/v1/nomenclature/${id}`)
    return response.data
  },
}

// API методы для паспортов
export const passportsAPI = {
  getAll: async (page: number = 1, page_size: number = 20) => {
    const response = await api.get(`/api/v1/passports/public-passports?page=${page}&page_size=${page_size}`)
    return response.data
  },

  getArchive: async () => {
    const response = await api.get('/api/v1/passports/archive/')
    return response.data
  },

  create: async (data: any) => {
    const response = await api.post('/api/v1/passports/', data)
    return response.data
  },

  createBulk: async (data: any) => {
    const response = await api.post('/api/v1/passports/bulk/', data)
    return response.data
  },

  getById: async (id: number) => {
    const response = await api.get(`/api/v1/passports/${id}`)
    return response.data
  },

  archive: async (id: number) => {
    const response = await api.post(`/api/v1/passports/${id}/archive`)
    return response.data
  },

  activate: async (id: number) => {
    const response = await api.post(`/api/v1/passports/${id}/activate`)
    return response.data
  },

  exportPdf: async (id: number) => {
    const response = await api.get(`/api/v1/passports/${id}/export/pdf`, {
      responseType: 'blob',
    })
    return response.data
  },

  exportPDF: async (id: number) => {
    const response = await api.get(`/api/v1/passports/${id}/export/pdf`, {
      responseType: 'blob',
    })
    return response.data
  },

  exportBulkPdf: async (passportIds: number[]) => {
    const response = await api.post('/api/v1/passports/export/bulk/pdf', passportIds, {
      responseType: 'blob',
    })
    return response.data
  },

  exportExcel: async () => {
    const response = await api.get('/api/v1/passports/export/excel', {
      responseType: 'blob',
    })
    return response.data
  },
  exportSelectedExcel: async (passportIds: number[]) => {
    const response = await api.post('/api/v1/passports/export/excel/selected', passportIds, {
      responseType: 'blob',
    })
    return response.data
  },
}

// API методы для пользователей (только для админов)
export const usersAPI = {
  getAll: async () => {
    const response = await api.get('/api/v1/users/')
    return response.data
  },

  create: async (data: any) => {
    const response = await api.post('/api/v1/users/', data)
    return response.data
  },

  update: async (id: number, data: any) => {
    const response = await api.put(`/api/v1/users/${id}`, data)
    return response.data
  },

  delete: async (id: number) => {
    const response = await api.delete(`/api/v1/users/${id}`)
    return response.data
  },
}

export default api

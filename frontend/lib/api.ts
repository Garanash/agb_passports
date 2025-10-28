import axios from 'axios'

// Типы для глобальной конфигурации
declare global {
  interface Window {
    API_CONFIG?: {
      API_URL: string
    }
  }
}

// Получаем настройки из переменных окружения или глобальной конфигурации
const API_BASE_URL = (typeof window !== 'undefined' && window.API_CONFIG?.API_URL) || 
                     process.env.NEXT_PUBLIC_API_URL || 
                     'http://localhost:8000'
const APP_NAME = process.env.NEXT_PUBLIC_APP_NAME || 'AGB Passports'
const APP_VERSION = process.env.NEXT_PUBLIC_APP_VERSION || '1.0.0'

// Определяем окружение
const isProduction = process.env.NODE_ENV === 'production'

// Создаем экземпляр axios с базовой конфигурацией
const api = axios.create({
  baseURL: API_BASE_URL || 'http://localhost:8000',
  headers: {
    'Content-Type': 'application/json',
    'X-App-Name': APP_NAME,
    'X-App-Version': APP_VERSION,
  },
  timeout: 30000, // 30 секунд таймаут
})

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
    const response = await api.get('/api/v1/auth/users/')
    return response.data
  },

  create: async (data: any) => {
    const response = await api.post('/api/v1/auth/users/', data)
    return response.data
  },

  update: async (id: number, data: any) => {
    const response = await api.patch(`/api/v1/auth/users/${id}`, data)
    return response.data
  },

  delete: async (id: number) => {
    const response = await api.delete(`/api/v1/auth/users/${id}`)
    return response.data
  },
}

export default api

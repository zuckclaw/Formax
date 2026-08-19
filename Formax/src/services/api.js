import axios from 'axios'

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('formax_token')

  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }

  return config
})

export const resolveApiData = (payload) => {
  if (!payload) return {}

  if (payload?.data !== undefined) {
    return payload.data
  }

  return payload
}

const normalizeUserPayload = (data) => {
  if (!data) return null

  if (data.user) return data.user
  if (data.profile) return data.profile
  if (data.data?.user) return data.data.user
  if (data.data?.profile) return data.data.profile
  if (data.id || data.email || data.name) return data

  return null
}

export const normalizeAuthResponse = (payload) => {
  const data = resolveApiData(payload)
  const token =
    data?.token ??
    data?.accessToken ??
    data?.access_token ??
    data?.jwt ??
    data?.data?.token ??
    data?.data?.accessToken ??
    data?.data?.access_token ??
    null

  const user = normalizeUserPayload(data) ?? normalizeUserPayload(payload)

  return {
    token,
    user,
    message: data?.message ?? data?.meta?.message ?? payload?.message ?? 'Success',
  }
}

export const requestWithFallbacks = async (method, endpoints, payload = null, config = {}) => {
  const candidates = [...new Set((endpoints || []).filter(Boolean))]

  if (!candidates.length) {
    throw new Error('Tidak ada endpoint yang tersedia untuk request ini.')
  }

  const routeVariants = candidates.flatMap((endpoint) => {
    const normalized = endpoint.startsWith('/') ? endpoint : `/${endpoint}`
    return [normalized, `/api${normalized}`]
  })

  const uniqueRoutes = [...new Set(routeVariants)]
  let lastError = null

  for (const route of uniqueRoutes) {
    try {
      return await api.request({
        method,
        url: route,
        data: payload,
        ...config,
      })
    } catch (error) {
      lastError = error
    }
  }

  throw lastError || new Error('Request gagal.')
}

export default api

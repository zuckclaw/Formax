import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import { normalizeAuthResponse, requestWithFallbacks } from '../services/api'

const AuthContext = createContext(null)

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(() => {
    const savedUser = localStorage.getItem('formax_user')
    return savedUser ? JSON.parse(savedUser) : null
  })
  const [token, setToken] = useState(() => localStorage.getItem('formax_token'))
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (token) {
      localStorage.setItem('formax_token', token)
    } else {
      localStorage.removeItem('formax_token')
    }
  }, [token])

  useEffect(() => {
    if (user) {
      localStorage.setItem('formax_user', JSON.stringify(user))
    } else {
      localStorage.removeItem('formax_user')
    }
  }, [user])

  const login = async (credentials) => {
    setLoading(true)

    try {
      const response = await requestWithFallbacks('post', ['/auth/login', '/login'], credentials)
      const { token: newToken, user: loggedUser } = normalizeAuthResponse(response.data)

      if (newToken) {
        setToken(newToken)
        setUser(loggedUser ?? { email: credentials.email, full_name: credentials.email.split('@')[0] })
        return response.data
      }
    } catch (error) {
      console.warn('Backend API login tidak merespon, menggunakan login fallback:', error)
    } finally {
      setLoading(false)
    }

    // Fallback Login jika backend offline/gagal
    const mockToken = 'mock_jwt_token_' + Date.now()
    const mockUser = {
      id: Date.now(),
      full_name: credentials.email ? credentials.email.split('@')[0] : 'Gita Nur',
      email: credentials.email,
    }
    setToken(mockToken)
    setUser(mockUser)
    return { token: mockToken, user: mockUser }
  }

  const register = async (payload) => {
    setLoading(true)

    try {
      const response = await requestWithFallbacks('post', ['/auth/signup', '/auth/register', '/register'], payload)
      const { token: newToken, user: registeredUser } = normalizeAuthResponse(response.data)

      if (newToken) {
        setToken(newToken)
        setUser(registeredUser ?? { email: payload.email, full_name: payload.full_name })
        return response.data
      }
    } catch (error) {
      console.warn('Backend API register tidak merespon, menggunakan registrasi fallback:', error)
    } finally {
      setLoading(false)
    }

    // Fallback Register jika backend offline/gagal
    const mockToken = 'mock_jwt_token_' + Date.now()
    const mockUser = {
      id: Date.now(),
      full_name: payload.full_name || (payload.email ? payload.email.split('@')[0] : 'Gita Nur'),
      email: payload.email,
    }
    setToken(mockToken)
    setUser(mockUser)
    return { token: mockToken, user: mockUser }
  }

  const logout = async () => {
    try {
      await requestWithFallbacks('post', ['/auth/logout', '/logout'], {})
    } catch (error) {
      console.warn('Logout API gagal, tetap keluar dari frontend:', error)
    } finally {
      setToken(null)
      setUser(null)
    }
  }

  const getProfile = async () => {
    if (!token) return null

    try {
      const response = await requestWithFallbacks('get', ['/auth/me', '/me'], null)
      const data = response.data?.data ?? response.data?.user ?? response.data
      setUser(data)
      return data
    } catch (error) {
      console.error('Gagal mengambil profile:', error)
      setToken(null)
      setUser(null)
      return null
    }
  }

  const value = useMemo(
    () => ({
      user,
      token,
      loading,
      login,
      register,
      logout,
      getProfile,
      isAuthenticated: Boolean(token && user),
    }),
    [user, token, loading],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export const useAuth = () => {
  const context = useContext(AuthContext)

  if (!context) {
    throw new Error('useAuth harus dipakai di dalam AuthProvider')
  }

  return context
}

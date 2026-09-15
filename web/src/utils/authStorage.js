const TOKEN_KEY = 'token'
const REFRESH_KEY = 'refresh_token'
const EXPIRES_KEY = 'auth_expires'
const REMEMBER_KEY = 'auth_remember'
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000

export function setAuth(token, remember = false, refreshToken = null) {
  // remember=true -> persist 30 hari di localStorage.
  // remember=false -> hanya sessionStorage agar hilang saat tab/browser ditutup
  // (privasi di komputer bersama). Tetap tulis localStorage? TIDAK — agar
  // getValidToken() tidak menghidupkan sesi non-remember lintas restart.
  try { sessionStorage.setItem(TOKEN_KEY, token) } catch { /* storage unavailable */ }
  const refresh = refreshToken || null
  try {
    if (refresh) sessionStorage.setItem(REFRESH_KEY, refresh)
    else sessionStorage.removeItem(REFRESH_KEY)
  } catch { /* storage unavailable */ }
  if (remember) {
    localStorage.setItem(TOKEN_KEY, token)
    localStorage.setItem(REMEMBER_KEY, 'true')
    localStorage.setItem(EXPIRES_KEY, String(Date.now() + THIRTY_DAYS_MS))
    try {
      if (refresh) localStorage.setItem(REFRESH_KEY, refresh)
      else localStorage.removeItem(REFRESH_KEY)
    } catch { /* storage unavailable */ }
  } else {
    localStorage.removeItem(TOKEN_KEY)
    localStorage.setItem(REMEMBER_KEY, 'false')
    localStorage.removeItem(EXPIRES_KEY)
    try { localStorage.removeItem(REFRESH_KEY) } catch { /* storage unavailable */ }
  }
}

export function getRefreshToken() {
  try {
    const s = sessionStorage.getItem(REFRESH_KEY)
    if (s) return s
  } catch { /* storage unavailable */ }
  try { return localStorage.getItem(REFRESH_KEY) } catch { return null }
}

export function getValidToken() {
  // Cek session dulu (non-remember), lalu localStorage (remember 30 hari).
  try {
    const sessionToken = sessionStorage.getItem(TOKEN_KEY)
    if (sessionToken) return sessionToken
  } catch { /* storage unavailable */ }
  const token = localStorage.getItem(TOKEN_KEY)
  if (!token) return null
  const remember = localStorage.getItem(REMEMBER_KEY) === 'true'
  // hanya cek expiry lokal untuk remember me 30 hari
  if (remember) {
    const exp = localStorage.getItem(EXPIRES_KEY)
    if (exp && Date.now() > Number(exp)) {
      clearAuth()
      return null
    }
  } else {
    // Token di localStorage tanpa flag remember = sesi lama (sebelum fix) —
    // masih diterima sampai JWT backend kedaluwarsa (7 hari), tapi sesi baru
    // non-remember sudah tidak ditulis ke localStorage lagi.
  }
  return token
}

export function isRemembered() {
  return localStorage.getItem(REMEMBER_KEY) === 'true' && !!getValidToken()
}

export function getRememberPreference() {
  try { return localStorage.getItem(REMEMBER_KEY) === 'true' } catch { return false }
}

export function clearAuth() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(REFRESH_KEY)
  localStorage.removeItem(EXPIRES_KEY)
  localStorage.removeItem(REMEMBER_KEY)
  localStorage.removeItem('user')
  try { sessionStorage.removeItem(TOKEN_KEY) } catch { /* storage unavailable */ }
  try { sessionStorage.removeItem(REFRESH_KEY) } catch { /* storage unavailable */ }
}

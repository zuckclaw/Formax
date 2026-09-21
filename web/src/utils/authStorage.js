const TOKEN_KEY = 'token'
const REFRESH_KEY = 'refresh_token'
const EXPIRES_KEY = 'auth_expires'
const REMEMBER_KEY = 'auth_remember'
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000

function safeGet(storage, key) {
  try { return storage.getItem(key) } catch { return null }
}
function safeSet(storage, key, value) {
  try { storage.setItem(key, value); return true } catch { return false }
}
function safeDel(storage, key) {
  try { storage.removeItem(key) } catch { /* ignore */ }
}

function notifyAuthChanged() {
  // Deferred (microtask) agar aman dipanggil dari jalur sinkron seperti
  // getValidToken() saat render — listener React tidak di-trigger
  // di tengah fase render (menghindari setState-during-render).
  const emit = () => {
    try {
      globalThis.dispatchEvent(new CustomEvent('auth:changed'));
    } catch { /* event API unavailable (SSR/test) */ }
  };
  try {
    if (typeof queueMicrotask === 'function') queueMicrotask(emit);
    else setTimeout(emit, 0);
  } catch {
    emit();
  }
}

export function setAuth(token, remember = false, refreshToken = null) {
  safeSet(sessionStorage, TOKEN_KEY, token)
  const refresh = refreshToken || null
  if (refresh) safeSet(sessionStorage, REFRESH_KEY, refresh)
  else safeDel(sessionStorage, REFRESH_KEY)
  if (remember) {
    safeSet(localStorage, TOKEN_KEY, token)
    safeSet(localStorage, REMEMBER_KEY, 'true')
    safeSet(localStorage, EXPIRES_KEY, String(Date.now() + THIRTY_DAYS_MS))
    if (refresh) safeSet(localStorage, REFRESH_KEY, refresh)
    else safeDel(localStorage, REFRESH_KEY)
  } else {
    safeDel(localStorage, TOKEN_KEY)
    safeSet(localStorage, REMEMBER_KEY, 'false')
    safeDel(localStorage, EXPIRES_KEY)
    safeDel(localStorage, REFRESH_KEY)
  }
  notifyAuthChanged()
}

export function getRefreshToken() {
  const s = safeGet(sessionStorage, REFRESH_KEY)
  if (s) return s
  return safeGet(localStorage, REFRESH_KEY)
}

export function getValidToken() {
  try {
    const sessionToken = safeGet(sessionStorage, TOKEN_KEY)
    if (sessionToken) return sessionToken
  } catch { /* treated as missing */ }
  let token
  let remember
  let exp
  try { token = localStorage.getItem(TOKEN_KEY) } catch { return null }
  if (!token) return null
  try { remember = localStorage.getItem(REMEMBER_KEY) === 'true' } catch { remember = false }
  if (remember) {
    try { exp = localStorage.getItem(EXPIRES_KEY) } catch { exp = null }
    if (exp && Date.now() > Number(exp)) {
      clearAuth()
      return null
    }
  }
  return token
}

export function isRemembered() {
  try { return localStorage.getItem(REMEMBER_KEY) === 'true' && !!getValidToken() } catch { return false }
}

export function getRememberPreference() {
  return safeGet(localStorage, REMEMBER_KEY) === 'true'
}

export function clearAuth() {
  safeDel(localStorage, TOKEN_KEY)
  safeDel(localStorage, REFRESH_KEY)
  safeDel(localStorage, EXPIRES_KEY)
  safeDel(localStorage, REMEMBER_KEY)
  safeDel(localStorage, 'user')
  safeDel(sessionStorage, TOKEN_KEY)
  safeDel(sessionStorage, REFRESH_KEY)
  notifyAuthChanged()
}

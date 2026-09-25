const _rawBase = (import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000').trim();
export const API_BASE_URL = _rawBase.replace(/\/+$/, '');

import { clearAuth, getRefreshToken, getRememberPreference, setAuth } from '../utils/authStorage.js';

if (!import.meta.env.VITE_API_BASE_URL && import.meta.env.PROD) {
  console.warn('[config] VITE_API_BASE_URL belum diset — fallback ke localhost. Set di URL_API Env.');
}

// Ambil atau buat anonymous identity untuk isi form tanpa login (Google-Forms style)
// Disimpan di localStorage agar persist antar reload / tabs
export function getRespondentKey() {
  try {
    let key = localStorage.getItem('respondent_key');
    if (!key) {
      key = (globalThis.crypto && globalThis.crypto.randomUUID)
        ? globalThis.crypto.randomUUID()
        : `rk_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
      localStorage.setItem('respondent_key', key);
    }
    return key;
  } catch {
    return null;
  }
}

// Wrapper fetch yang otomatis inject header bypass ngrok warning page
// Ngrok free (ngrok-free.dev) menampilkan halaman interstitial jika header ini tidak ada,
// yang menyebabkan CORS error di browser meski status 200.
async function fetchWithTimeout(url, options, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await globalThis.fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function refreshAccessToken(timeoutMs) {
  const refreshToken = getRefreshToken();
  if (!refreshToken) return null;
  try {
    const response = await fetchWithTimeout(`${API_BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: JSON.stringify({ refresh_token: refreshToken }),
    }, Math.min(timeoutMs, 10000));
    if (!response.ok) return null;
    const data = await response.json();
    if (!data?.access_token) return null;
    setAuth(data.access_token, getRememberPreference(), data.refresh_token || refreshToken);
    return data.access_token;
  } catch {
    return null;
  }
}

export async function apiFetch(url, options = {}, timeoutMs = 30000) {
  const headers = {
    'ngrok-skip-browser-warning': 'true',
    ...(options.headers || {}),
  };
  const { _skipAuthRefresh = false, ...requestOptions } = options;
  try {
    const response = await fetchWithTimeout(url, { ...requestOptions, headers }, timeoutMs);
    const hasAuthorization = Object.keys(headers).some((key) => key.toLowerCase() === 'authorization');
    const isRefreshRequest = url.endsWith('/auth/refresh');
    if (response.status !== 401 || _skipAuthRefresh || !hasAuthorization || isRefreshRequest) {
      return response;
    }

    const accessToken = await refreshAccessToken(timeoutMs);
    if (!accessToken) return response;

    const retryHeaders = { ...headers, Authorization: `Bearer ${accessToken}` };
    return fetchWithTimeout(url, { ...requestOptions, headers: retryHeaders }, timeoutMs);
  } catch (e) {
    if (e && (e.name === 'AbortError' || e.name === 'TimeoutError')) {
      throw new Error('Permintaan timeout — periksa koneksi internet Anda lalu coba lagi.', { cause: e });
    }
    throw new Error('Gagal terhubung ke server — periksa koneksi internet Anda lalu coba lagi.', { cause: e });
  }
}

// Helper untuk header auth anonim: Authorization (jika ada token) + X-Respondent-Key (selalu)
export function getAuthHeaders(token) {
  const headers = {};
  if (token && token !== 'null' && token !== 'undefined') headers['Authorization'] = `Bearer ${token}`;
  const rkey = getRespondentKey();
  if (rkey) headers['X-Respondent-Key'] = rkey;
  return headers;
}

export async function readJsonResponse(res, fallbackMessage) {
  let json;

  try {
    // 204 No Content — sukses tanpa body (mis. DELETE).
    if (res.status === 204) return null;
    const text = await res.text();
    json = text ? JSON.parse(text) : undefined;
  } catch {
    // Ignore JSON parse error, json remains undefined
    json = undefined;
  }

  if (!res.ok) {
    if (res.status === 404 && json?.detail === 'Not Found') {
      throw new Error('Endpoint backend belum tersedia atau server backend belum direstart.');
    }
    const detail = typeof json?.detail === 'string' ? json.detail : null;
    // Sesi kedaluwarsa: bersihkan token + beri tahu App agar redirect ke /auth.
    // Jangan clear saat login gagal ("Email atau password salah") — itu bukan sesi expired.
    if (res.status === 401 && detail && /kadaluarsa|tidak valid/i.test(detail)) {
      try {
        clearAuth();
      } catch { /* storage unavailable */ }
      try {
        globalThis.dispatchEvent(new CustomEvent('auth:expired', { detail: { message: detail } }));
      } catch { /* event API unavailable */ }
    }
    // Abort timeout → pesan ramah, bukan "The operation was aborted".
    if (fallbackMessage && typeof DOMException !== 'undefined' && detail === null && json === undefined) {
      // json undefined + !ok tanpa detail biasanya network/timeout — biarkan pesan fallback.
    }
    throw new Error(detail || `${fallbackMessage} (HTTP ${res.status})`);
  }

  if (json === undefined) {
    throw new Error(`${fallbackMessage} (respons bukan JSON)`);
  }

  return json;
} 
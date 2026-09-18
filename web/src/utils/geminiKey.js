/**
 * geminiKey — penyimpanan API key Gemini milik user (BYOK) di browser.
 * - Default: sessionStorage (hilang saat tab ditutup) — aman untuk perangkat bersama.
 * - Opt-in "ingat": localStorage.
 * - Key TIDAK PERNAH dikirim kecuali ke endpoint /ai/* via header X-Gemini-API-Key.
 */

const SESSION_KEY = 'formax_gemini_key_session';
const LOCAL_KEY = 'formax_gemini_key_remember';

function safeGet(storage, k) {
  try {
    return storage.getItem(k) || '';
  } catch {
    return '';
  }
}

export function getOwnGeminiKey() {
  const session = safeGet(sessionStorage, SESSION_KEY).trim();
  if (session) return { key: session, remembered: false };
  const local = safeGet(localStorage, LOCAL_KEY).trim();
  if (local) return { key: local, remembered: true };
  return { key: '', remembered: false };
}

export function hasOwnGeminiKey() {
  return getOwnGeminiKey().key.length >= 20;
}

export function setOwnGeminiKey(key, remember = false) {
  const v = String(key || '').trim();
  try {
    sessionStorage.removeItem(SESSION_KEY);
    localStorage.removeItem(LOCAL_KEY);
    if (!v) return;
    if (remember) localStorage.setItem(LOCAL_KEY, v);
    else sessionStorage.setItem(SESSION_KEY, v);
  } catch {
    /* storage unavailable — key hanya hidup di memori pemanggil */
  }
}

export function clearOwnGeminiKey() {
  try {
    sessionStorage.removeItem(SESSION_KEY);
    localStorage.removeItem(LOCAL_KEY);
  } catch {
    /* abaikan */
  }
}

export function maskGeminiKey(key) {
  const k = String(key || '');
  if (k.length <= 4) return '••••';
  return `••••${k.slice(-4)}`;
}

export function looksLikeGeminiKey(key) {
  const k = String(key || '').trim();
  return k.length >= 20 && k.length <= 300;
}

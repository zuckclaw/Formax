import { API_BASE_URL, apiFetch, getAuthHeaders, readJsonResponse } from './config';
import { getOwnGeminiKey } from '../utils/geminiKey';

// Header BYOK: kunci Gemini milik user (jika ada) — server mengutamakan ini
// dari API key milik server. Tidak disimpan di mana pun selain browser user.
function byokHeaders() {
  try {
    const { key } = getOwnGeminiKey();
    if (key && key.length >= 20) return { 'X-Gemini-API-Key': key };
  } catch {
    /* abaikan */
  }
  return {};
}

export async function generateAiForm(token, payload, signal) {
  // Generate AI bisa 20-60 detik (LLM + failover antar model) — jangan pakai
  // timeout default 30 dtk agar tidak abort dini saat backend masih bekerja.
  const res = await apiFetch(`${API_BASE_URL}/ai/generate-form`, {
    method: 'POST',
    headers: { ...getAuthHeaders(token), ...byokHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
    ...(signal ? { signal } : {}),
  }, 120000);
  return readJsonResponse(res, 'Gagal generate form dengan AI');
}

// Cek API key Gemini milik user via ListModels (tanpa memakai kuota generate).
export async function validateGeminiKey(token, key) {
  const res = await apiFetch(`${API_BASE_URL}/ai/validate-key`, {
    method: 'POST',
    headers: { ...getAuthHeaders(token), 'X-Gemini-API-Key': String(key || '').trim() },
  }, 20000);
  return readJsonResponse(res, 'Gagal memeriksa API key');
}

export async function extractAiFileText(token, file) {
  const formData = new FormData();
  formData.append('file', file);

  const res = await apiFetch(`${API_BASE_URL}/ai/extract-file`, {
    method: 'POST',
    headers: {
      ...getAuthHeaders(token),
    },
    body: formData,
  });
  return readJsonResponse(res, 'Gagal membaca file terlampir');
}

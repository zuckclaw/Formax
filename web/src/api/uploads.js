import { API_BASE_URL, apiFetch, getAuthHeaders } from './config';

/**
 * Upload file (banner form, avatar, dll). Kembalikan { file_url }.
 * Support login (Bearer) ATAU anonim (X-Respondent-Key) — konsisten dengan backend deps.py
 * Fix: sebelumnya kirim "Bearer null" saat token kosong → 401 di flow anon.
 */
export async function uploadFile(token, file) {
  const formData = new FormData();
  formData.append('file', file);
  let res;
  try {
    res = await apiFetch(`${API_BASE_URL}/uploads`, {
      method: 'POST',
      headers: { ...getAuthHeaders(token) },
      body: formData,
    });
  } catch (e) {
    // Network / CORS / ngrok down
    if (e.message?.includes('Failed to fetch') || e.name === 'TypeError') {
      throw new Error('Gagal terhubung ke server — cek ngrok masih nyala & VITE_API_BASE_URL benar');
    }
    throw e;
  }
  // 503 = ngrok tunnel mati (CORS Missing Allow Origin di console)
  if (res.status === 503) {
    throw new Error('Server ngrok 503 — tunnel mati. Jalankan `ngrok http 8000` lagi & pastikan URL di API sama');
  }
  let json;
  try {
    json = await res.json();
  } catch {
    if (!res.ok) throw new Error(`Upload gagal (HTTP ${res.status}) — cek backend & ngrok`);
    throw new Error('Response upload bukan JSON');
  }
  if (!res.ok) throw new Error(json.detail || `Gagal mengupload file (HTTP ${res.status})`);
  return json;
}

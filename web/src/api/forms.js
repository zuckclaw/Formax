import { API_BASE_URL, apiFetch, getAuthHeaders, readJsonResponse } from './config';

/**
 * List semua form milik user (untuk halaman History / Recent History)
 */
export async function getMyForms(token) {
  const res = await apiFetch(`${API_BASE_URL}/forms`, {
    headers: { ...getAuthHeaders(token) },
  });
  return readJsonResponse(res, 'Gagal mengambil daftar form');
}

/**
 * Buat form baru (blank atau dari template)
 */
export async function createForm(token, data) {
  const res = await apiFetch(`${API_BASE_URL}/forms`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeaders(token),
    },
    body: JSON.stringify(data),
  });
  return readJsonResponse(res, 'Gagal membuat form');
}

/**
 * Get detail form (owner only)
 */
export async function getForm(token, formId) {
  const res = await apiFetch(`${API_BASE_URL}/forms/${encodeURIComponent(formId)}`, {
    headers: { ...getAuthHeaders(token) },
  });
  return readJsonResponse(res, 'Gagal mengambil form');
}

/**
 * Update form (title, description, status, dates, etc.)
 */
export async function updateForm(token, formId, data) {
  const res = await apiFetch(`${API_BASE_URL}/forms/${encodeURIComponent(formId)}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeaders(token),
    },
    body: JSON.stringify(data),
  });
  return readJsonResponse(res, 'Gagal mengupdate form');
}

/**
 * Hapus form
 */
export async function deleteForm(token, formId) {
  const res = await apiFetch(`${API_BASE_URL}/forms/${encodeURIComponent(formId)}`, {
    method: 'DELETE',
    headers: { ...getAuthHeaders(token) },
  });
  return readJsonResponse(res, 'Gagal menghapus form');
}

/**
 * Generate QR code untuk form
 */
export async function generateQR(token, formId) {
  const res = await apiFetch(`${API_BASE_URL}/forms/${formId}/generate-qr`, {
    method: 'POST',
    headers: { ...getAuthHeaders(token) },
  });
  return readJsonResponse(res, 'Gagal generate QR');
}

/**
 * Get daftar submission untuk form tertentu (Owner only)
 */
export async function getFormSubmissions(token, formId) {
  const res = await apiFetch(`${API_BASE_URL}/forms/${formId}/submissions`, {
    headers: { ...getAuthHeaders(token) },
  });
  return readJsonResponse(res, 'Gagal mengambil hasil respons');
}

/**
 * Ekspor jawaban form ke file Excel (.xlsx)
 */
export async function exportSubmissions(token, formId, formSlug = 'form') {
  const res = await apiFetch(`${API_BASE_URL}/forms/${formId}/export`, {
    headers: { ...getAuthHeaders(token) },
  });
  if (!res.ok) {
    let detail = 'Gagal mengekspor data ke Excel';
    try {
      const ct = res.headers.get('content-type') || '';
      if (ct.includes('application/json')) {
        const j = await res.json();
        if (typeof j?.detail === 'string') detail = j.detail;
      }
    } catch { /* abaikan, pakai pesan default */ }
    throw new Error(`${detail} (HTTP ${res.status})`);
  }
  const ct = res.headers.get('content-type') || '';
  if (ct.includes('application/json')) {
    // Backend mengirim error JSON tapi status 200 — jangan simpan sebagai xlsx rusak.
    try {
      const j = await res.json();
      throw new Error(j?.detail || 'Gagal mengekspor data ke Excel');
    } catch (e) {
      if (e.message && !e.message.includes('Unexpected')) throw e;
    }
  }
  const blob = await res.blob();
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${formSlug}-hasil.xlsx`;
  document.body.appendChild(a);
  try {
    a.click();
  } finally {
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
  }
}

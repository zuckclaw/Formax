import { API_BASE_URL, apiFetch, getAuthHeaders, readJsonResponse } from './config';

/**
 * Download template Word (.docx) untuk import soal
 */
export async function downloadTemplateDocx(token) {
  const res = await apiFetch(`${API_BASE_URL}/import/template-docx`, {
    headers: { ...getAuthHeaders(token) },
  });

  if (!res.ok) {
    let msg = `Gagal mengunduh template (HTTP ${res.status})`;
    try {
      const ct = res.headers.get('content-type') || '';
      if (ct.includes('application/json')) {
        const json = await res.json();
        if (typeof json?.detail === 'string') msg = json.detail;
      }
    } catch { /* pakai pesan default */ }
    throw new Error(msg);
  }

  const blob = await res.blob();
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'template-import-soal.docx';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  window.URL.revokeObjectURL(url);
}

/**
 * Preview upload DOCX — parse soal dan return daftar soal + validasi
 */
export async function previewDocxImport(token, formId, file) {
  const formData = new FormData();
  formData.append('file', file);

  const res = await apiFetch(`${API_BASE_URL}/forms/${formId}/questions/import-docx/preview`, {
    method: 'POST',
    headers: { ...getAuthHeaders(token) },
    body: formData,
  });

  return readJsonResponse(res, 'Gagal memproses file DOCX');
}

/**
 * Confirm import — kirim soal-soal yang dipilih ke server
 */
export async function confirmDocxImport(token, formId, questions) {
  const res = await apiFetch(`${API_BASE_URL}/forms/${formId}/questions/import-docx/confirm`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeaders(token),
    },
    body: JSON.stringify({ questions }),
  });

  return readJsonResponse(res, 'Gagal mengimpor soal');
}

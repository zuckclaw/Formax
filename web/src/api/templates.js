import { API_BASE_URL, apiFetch, readJsonResponse } from './config';

/**
 * List semua template (system + user templates)
 */
export async function getTemplates(token) {
  const res = await apiFetch(`${API_BASE_URL}/templates`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  return readJsonResponse(res, 'Gagal mengambil templates');
}

/**
 * Get detail template (termasuk questions)
 */
export async function getTemplate(token, templateId) {
  const res = await apiFetch(`${API_BASE_URL}/templates/${templateId}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return readJsonResponse(res, 'Gagal mengambil template');
}

/**
 * List template buatan sendiri saja
 */
export async function getMyTemplates(token) {
  const res = await apiFetch(`${API_BASE_URL}/templates/mine`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  return readJsonResponse(res, 'Gagal mengambil templates');
}

/**
 * Buat template baru (judul, deskripsi, dan daftar soal+opsi)
 */
export async function createTemplate(token, data) {
  const res = await apiFetch(`${API_BASE_URL}/templates`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(data),
  });
  return readJsonResponse(res, 'Gagal membuat template');
}

/**
 * Hapus template milik sendiri
 */
export async function deleteTemplate(token, templateId) {
  const res = await apiFetch(`${API_BASE_URL}/templates/${templateId}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
  return readJsonResponse(res, 'Gagal menghapus template');
}
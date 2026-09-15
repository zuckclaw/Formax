import { API_BASE_URL, apiFetch, getAuthHeaders, readJsonResponse } from './config';

// ============================================================
// QUESTIONS
// ============================================================

/**
 * Tambah pertanyaan ke form
 */
export async function createQuestionInForm(token, formId, data) {
  const res = await apiFetch(`${API_BASE_URL}/forms/${formId}/questions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeaders(token),
    },
    body: JSON.stringify(data),
  });
  return readJsonResponse(res, 'Gagal menambah pertanyaan');
}

/**
 * Update pertanyaan
 */
export async function updateQuestion(token, questionId, data) {
  const res = await apiFetch(`${API_BASE_URL}/questions/${questionId}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeaders(token),
    },
    body: JSON.stringify(data),
  });
  return readJsonResponse(res, 'Gagal mengupdate pertanyaan');
}

/**
 * Hapus pertanyaan
 */
export async function deleteQuestion(token, questionId) {
  const res = await apiFetch(`${API_BASE_URL}/questions/${questionId}`, {
    method: 'DELETE',
    headers: { ...getAuthHeaders(token) },
  });
  return readJsonResponse(res, 'Gagal menghapus pertanyaan');
}

// ============================================================
// OPTIONS
// ============================================================

/**
 * Tambah opsi ke pertanyaan
 */
export async function createOption(token, questionId, data) {
  const res = await apiFetch(`${API_BASE_URL}/questions/${questionId}/options`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeaders(token),
    },
    body: JSON.stringify(data),
  });
  return readJsonResponse(res, 'Gagal menambah opsi');
}

/**
 * Update opsi
 */
export async function updateOption(token, optionId, data) {
  const res = await apiFetch(`${API_BASE_URL}/options/${optionId}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeaders(token),
    },
    body: JSON.stringify(data),
  });
  return readJsonResponse(res, 'Gagal mengupdate opsi');
}

/**
 * Hapus opsi
 */
export async function deleteOption(token, optionId) {
  const res = await apiFetch(`${API_BASE_URL}/options/${optionId}`, {
    method: 'DELETE',
    headers: { ...getAuthHeaders(token) },
  });
  return readJsonResponse(res, 'Gagal menghapus opsi');
}

import { API_BASE_URL, apiFetch, getAuthHeaders, readJsonResponse } from './config';

export async function generateAiForm(token, payload, signal) {
  const res = await apiFetch(`${API_BASE_URL}/ai/generate-form`, {
    method: 'POST',
    headers: { ...getAuthHeaders(token), 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
    ...(signal ? { signal } : {}),
  });
  return readJsonResponse(res, 'Gagal generate form dengan AI');
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

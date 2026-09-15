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

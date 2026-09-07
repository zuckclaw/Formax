import { API_BASE_URL, getAuthHeaders, readJsonResponse } from './config';

export async function generateAiForm(token, payload) {
  const res = await fetch(`${API_BASE_URL}/ai/generate-form`, {
    method: 'POST',
    headers: { ...getAuthHeaders(token), 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return readJsonResponse(res, 'Gagal generate form dengan AI');
}

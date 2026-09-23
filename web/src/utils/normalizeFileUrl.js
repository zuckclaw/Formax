import { API_BASE_URL } from '../api/config';

const _STATIC_PATH_RE = /\/static\/(uploads|qrcodes)\//;

export function normalizeFileUrl(url) {
  if (!url || typeof url !== 'string') return url;
  const s = url.trim();
  if (!s) return s;

  if (s.startsWith('/static/')) {
    return `${API_BASE_URL}${s}`;
  }

  if (s.startsWith('data:') || s.startsWith('blob:')) return s;

  const match = s.match(_STATIC_PATH_RE);
  if (match) {
    try {
      const parsed = new URL(s);
      const apiParsed = new URL(API_BASE_URL);
      if (parsed.hostname === apiParsed.hostname && parsed.port !== apiParsed.port) {
        return `${API_BASE_URL}${parsed.pathname}`;
      }
      if (
        (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1') &&
        (apiParsed.hostname === 'localhost' || apiParsed.hostname === '127.0.0.1')
      ) {
        return `${API_BASE_URL}${parsed.pathname}`;
      }
    } catch {
      return s;
    }
  }

  return s;
}

export function normalizeHtmlImageUrls(html) {
  if (!html || typeof html !== 'string') return html;
  return html.replace(/(<img\s[^>]*?src=["'])([^"']+)(["'])/gi, (_m, prefix, src, suffix) => {
    return `${prefix}${normalizeFileUrl(src)}${suffix}`;
  }).replace(/(<audio\s[^>]*?src=["'])([^"']+)(["'])/gi, (_m, prefix, src, suffix) => {
    return `${prefix}${normalizeFileUrl(src)}${suffix}`;
  });
}

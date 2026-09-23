# Image Loading Fix — Comprehensive Analysis & Solutions

## Problem Analysis

### Root Cause
Images in banner dan form (soal) gagal memuat karena URL yang dikembalikan backend memiliki port yang salah atau hardcoded. Ketika uvicorn berjalan di port **8001** (bukan 8000), URL gambar menjadi:
- `http://127.0.0.1:8001/static/uploads/xxx.png` (SALAH — port tidak sesuai dengan akses frontend)

Ini terjadi di 3 tempat:
1. **uploads.py** — fallback ke `request.base_url` yang include port aktual
2. **forms.py** — `BASE_URL` hardcoded ke `http://localhost:8000`
3. **import_docx.py** — juga pakai `request.base_url`

Frontend tidak bisa load URL karena:
- Port di URL tidak sesuai dengan port yang diakses browser
- Tidak ada normalisasi URL ke `API_BASE_URL` yang benar

---

## Solutions Implemented

### Backend Fixes

#### 1. **uploads.py** (lines 101-105)
**Sebelum:**
```python
if not BASE_URL:
    url_base = str(request.base_url).rstrip("/")
else:
    url_base = BASE_URL
return {"file_url": f"{url_base}/static/uploads/{filename}"}
```

**Sesudah:**
```python
if BASE_URL:
    url_base = BASE_URL
    return {"file_url": f"{url_base}/static/uploads/{filename}"}
return {"file_url": f"/static/uploads/{filename}"}
```

**Keuntungan:** 
- Saat `BASE_URL` kosong (dev mode) → return path relatif `/static/uploads/xxx.png`
- Frontend yang determine origin yang benar menggunakan `API_BASE_URL`
- Tidak ada hardcoded port yang salah

#### 2. **forms.py** (lines 435-439)
**Sebelum:**
```python
if not BASE_URL:
    qr_base = str(request.base_url).rstrip("/")
else:
    qr_base = BASE_URL
form.qr_code_url = f"{qr_base}/static/qrcodes/{safe_slug}.png"
```

**Sesudah:**
```python
if BASE_URL:
    qr_base = BASE_URL
    form.qr_code_url = f"{qr_base}/static/qrcodes/{safe_slug}.png"
else:
    form.qr_code_url = f"/static/qrcodes/{safe_slug}.png"
```

**Keuntungan:** Sama seperti uploads.py — QR code URL juga relatif ketika `BASE_URL` kosong

#### 3. **import_docx.py** (lines 19-20, 64)
**Sebelum:**
```python
# line 60
base_url = str(request.base_url) if request is not None else ""
```

**Sesudah:**
```python
# Added at top
BASE_URL = os.getenv("BASE_URL", "").strip().rstrip("/")

# line 64
base_url = BASE_URL if BASE_URL else ""
```

**Keuntungan:** Konsisten dengan upload.py dan forms.py — gunakan env BASE_URL, bukan request.base_url

---

### Frontend Fixes

#### 1. **New File: utils/normalizeFileUrl.js**
Utility baru untuk normalize URL:
- Convert path relatif `/static/...` → URL absolut menggunakan `API_BASE_URL`
- Detect URL localhost dengan port salah → rewrite dengan `API_BASE_URL` yang benar
- Preserve URL ngrok, data: URL, blob: URL

```javascript
export function normalizeFileUrl(url) {
  if (!url || typeof url !== 'string') return url;
  const s = url.trim();
  if (!s) return s;

  if (s.startsWith('/static/')) {
    return `${API_BASE_URL}${s}`;  // Convert relative → absolute
  }

  if (s.startsWith('data:') || s.startsWith('blob:')) return s;

  const match = s.match(_STATIC_PATH_RE);
  if (match) {
    // Detect port mismatch pada localhost
    try {
      const parsed = new URL(s);
      const apiParsed = new URL(API_BASE_URL);
      if (parsed.hostname === apiParsed.hostname && parsed.port !== apiParsed.port) {
        return `${API_BASE_URL}${parsed.pathname}`;  // Rewrite port
      }
    } catch {
      return s;
    }
  }

  return s;
}
```

#### 2. **Updated: safeHtml.js**
`safeHtml()` sekarang otomatis normalize semua URL dalam HTML:
- Calls `normalizeHtmlImageUrls()` setelah sanitasi
- Affect semua render rich text: form description, soal label, opsi label
- Transparently fix URL di banner/soal tanpa perlu ubah component

#### 3. **Updated: NgrokImage.jsx**
Normalize `src` prop sebelum render:
```javascript
import { normalizeFileUrl } from '../utils/normalizeFileUrl';

const cleanSrc = normalizeFileUrl((src || '').trim());
```

#### 4. **Updated: FormFillPage.jsx**
- Normalize URL dalam `fixNgrokMediaInContainer()` sebelum fetch
- `richHtml()` sekarang menggunakan normalized URLs via `safeHtml()`

#### 5. **Updated: FormBuilderPage.jsx**
Banner upload handler normalize URL setelah dapat response dari backend

---

## How It Works Now

### Flow Chart
```
1. User upload banner/image di form builder
   ↓
2. Frontend kirim file ke POST /uploads
   ↓
3. Backend save file, return JSON:
   - Jika BASE_URL env ada  → return { "file_url": "https://api.example.com/static/uploads/xxx.png" }
   - Jika BASE_URL kosong   → return { "file_url": "/static/uploads/xxx.png" }
   ↓
4. Frontend receive response
   ↓
5. normalizeFileUrl() normalize URL:
   - Relative path → convert to absolute using API_BASE_URL
   - Wrong port → rewrite with correct API_BASE_URL
   - Absolute URL → pass through
   ↓
6. Store URL di formData
   ↓
7. Saat render:
   - Banner: NgrokImage component normalize URL lagi sebelum display
   - Form content: safeHtml() normalize URL di HTML sebelum render
   ↓
8. Image load dengan URL yang BENAR ✅
```

### Environment Variables
Tidak perlu ubah `.env` — semua auto-adjust:

**web/.env**
```
VITE_API_BASE_URL=https://wriggly-diffusion-flatfoot.ngrok-free.dev
```

**backend/.env**
```
# Kosongkan atau isi dengan domain publik
BASE_URL=
# atau saat deploy:
# BASE_URL=https://api.example.com
```

---

## Testing

### Backend
✅ Python compile check — OK
- `app/routers/uploads.py` 
- `app/routers/forms.py`
- `app/routers/import_docx.py`
- `app/utils/docx_import.py`

### Frontend
✅ npm lint — OK (no new errors related to changes)
✅ Files updated:
- `src/utils/normalizeFileUrl.js` (NEW)
- `src/utils/safeHtml.js` (UPDATED)
- `src/components/NgrokImage.jsx` (UPDATED)
- `src/pages/FormFillPage.jsx` (UPDATED)
- `src/pages/FormBuilderPage.jsx` (UPDATED)

### Mobile
✅ Already has proper URL normalization:
- `lib/widgets/ngrok_image.dart` — `resolveUrl()` function
- `lib/utils/quill_html.dart` — `resolveImageUrl()` + `normalizeHtmlForDisplay()`
✅ No changes needed — mobile akan auto-work dengan backend changes

---

## Deployment Checklist

- [ ] Test locally dengan port 8001 — gambar di banner dan soal harus load
- [ ] Test dengan ngrok tunnel — gambar harus load
- [ ] Test di Vercel — pastikan `VITE_API_BASE_URL` benar di env var
- [ ] Deploy backend — set `BASE_URL` env di production (biarkan kosong untuk local dev)
- [ ] Deploy frontend — pastikan `VITE_API_BASE_URL` di Vercel env var

---

## Summary of Changes

| File | Type | Change | Impact |
|------|------|--------|--------|
| `backend/app/routers/uploads.py` | Backend | Return relative path when `BASE_URL` empty | Fix: upload image port mismatch |
| `backend/app/routers/forms.py` | Backend | Return relative path for QR when `BASE_URL` empty | Fix: QR code port mismatch |
| `backend/app/routers/import_docx.py` | Backend | Use `BASE_URL` env instead of `request.base_url` | Fix: import docx image port mismatch |
| `web/src/utils/normalizeFileUrl.js` | Frontend | NEW utility | Normalize all URLs to correct port |
| `web/src/utils/safeHtml.js` | Frontend | Auto-normalize URLs in HTML | Fix: images in rich text |
| `web/src/components/NgrokImage.jsx` | Frontend | Normalize src prop | Fix: banner image display |
| `web/src/pages/FormFillPage.jsx` | Frontend | Normalize URLs in fixNgrokMediaInContainer | Fix: form content images |
| `web/src/pages/FormBuilderPage.jsx` | Frontend | Normalize banner upload URL | Fix: form builder preview |
| `mobile/lib/widgets/ngrok_image.dart` | Mobile | No changes | Already has proper URL resolution |
| `mobile/lib/utils/quill_html.dart` | Mobile | No changes | Already normalizes image URLs |

---

## Key Takeaway

**Semua URL untuk gambar/file sekarang auto-normalize ke `API_BASE_URL` yang benar, baik di web maupun mobile. Port 8000, 8001, atau apapun tidak masalah — frontend yang handle.**

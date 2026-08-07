# Formax

Formax adalah aplikasi form management dashboard untuk membuat form, membuat template, mengelola respon, dan mengekspor data CSV.

## Fitur utama
- Login dan register
- Dashboard KPI
- Manajemen form
- Builder form drag-free berbasis pertanyaan
- Template form reusable
- Submit form pengguna
- Lihat respon form
- Export CSV dari respon
- Routing aman dengan auth guard

## Kontrak API yang dipakai frontend
Berikut adalah kontrak yang dipakai agar frontend tetap konsisten dan tidak menunggu backend lain:

1. Autentikasi: JWT bearer token.
2. Base URL API: http://localhost:8000
3. Format login/register:
   {
     "success": true,
     "message": "congratulations your account has been made, welcome \"user\"",
     "data": {
       "token": "jwt_token_here",
       "user": {
         "id": 1,
         "name": "User",
         "email": "user@example.com",
         "role": "owner"
       }
     }
   }
4. Struktur user untuk frontend:
   {
     "id": 1,
     "name": "User",
     "email": "user@example.com",
     "role": "owner"
   }
5. Struktur form:
   {
     "id": 1,
     "title": "Judul form",
     "description": "Deskripsi form",
     "slug": "judul-form",
     "status": "Draft | Published",
     "created_by": 1,
     "questions": []
   }
6. Struktur template:
   {
     "id": 1,
     "title": "Template survey",
     "description": "Deskripsi template",
     "questions": []
   }
7. Struktur question:
   {
     "id": 1,
     "label": "Pertanyaan",
     "type": "text | email | textarea | radio | checkbox | dropdown | file",
     "required": true,
     "options": [
       { "id": 1, "label": "Pilihan A" }
     ]
   }
8. Struktur submission:
   {
     "id": 1,
     "form_id": 1,
     "submitted_at": "2026-08-06T10:00:00Z",
     "answers": {
       "1": "jawaban",
       "2": ["A", "B"]
     }
   }
9. Tipe question yang didukung: text, email, textarea, radio, checkbox, dropdown, file.
10. Validasi field dibuat oleh frontend sendiri sesuai kebutuhan, dengan rule umum:
    - title wajib diisi
    - label pertanyaan wajib diisi
    - required boleh boolean
    - option wajib diisi untuk radio / checkbox / dropdown
    - file hanya untuk tipe file, size ditentukan backend/frontend sendiri
11. Publish form: cukup update field status dari Draft ke Published via PATCH /forms/:id.
12. Role user: hanya ada 1 owner yang bikin form dan respondent untuk menjawab form. Untuk frontend tetap dipakai role owner/respondent.
13. Format error response: bebas, tetapi frontend menangani field message atau error.message.
14. Upload file: frontend mengatur sendiri batasan file sesuai kebutuhan, misalnya max 2MB, tipe file terbatas image/* atau .pdf, .docx.

## Setup lokal
1. Install dependency:
   npm install
2. Salin file konfigurasi:
   copy .env.example .env.local
3. Jalankan dev server:
   npm run dev
4. Akses aplikasi di browser:
   http://localhost:5173

## Konfigurasi backend
Buat file .env.local di root project jika ingin menyambungkan API backend yang nyata:

VITE_API_BASE_URL=http://localhost:8000

Jika backend belum aktif, frontend akan otomatis memakai mock data agar flow tetap berjalan.

## Build produksi
npm run build

## Preview build produksi untuk deploy lokal
npm run preview

## Jalankan tanpa env khusus
npm run start

## Catatan deploy lokal
Untuk deploy lokal, cukup jalankan build produksi lalu gunakan preview Vite di mesin lokal Anda, atau arahkan hasil build ke server statis yang mendukung hosting SPA.

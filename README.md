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

VITE_API_BASE_URL=http://localhost:8000/api

Jika backend belum aktif, frontend akan otomatis memakai mock data agar flow tetap berjalan.

## Build produksi
npm run build

## Preview build produksi untuk deploy lokal
npm run preview

## Jalankan tanpa env khusus
npm run start

## Catatan deploy lokal
Untuk deploy lokal, cukup jalankan build produksi lalu gunakan preview Vite di mesin lokal Anda, atau arahkan hasil build ke server statis yang mendukung hosting SPA.

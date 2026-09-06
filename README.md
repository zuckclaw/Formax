# Form4X — Platform Pembuat Formulir Digital

Form4X adalah aplikasi pembuat formulir digital bergaya modern yang tersedia dalam versi **Web** dan **Mobile**. Aplikasi ini memungkinkan pengguna membuat, mengelola, membagikan, dan menganalisis formulir secara menyeluruh — mulai dari survei, pendaftaran, absensi, kuis, hingga pengumpulan data umum — dengan pengalaman yang familiar, cepat, dan responsif.

**Demo Web:** `https://formax-seven.vercel.app`  

---

## Daftar Isi

- [Tentang Proyek](#tentang-proyek)
- [Fitur Utama](#fitur-utama)
- [Teknologi](#teknologi)
- [Arsitektur dan Diagram](#arsitektur-dan-diagram)
- [Struktur Proyek](#struktur-proyek)
- [Prasyarat](#prasyarat)
- [Instalasi dan Menjalankan Lokal](#instalasi-dan-menjalankan-lokal)
- [Konfigurasi Lingkungan](#konfigurasi-lingkungan)
- [Alur Penggunaan](#alur-penggunaan)
- [Tipe Pertanyaan](#tipe-pertanyaan)
- [Dokumentasi API](#dokumentasi-api)
- [QR Code dan Berbagi Formulir](#qr-code-dan-berbagi-formulir)
- [Ekspor dan Analisis Respons](#ekspor-dan-analisis-respons)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [Kontribusi](#kontribusi)
- [Lisensi](#lisensi)

---

## Tentang Proyek

Form4X dibangun sebagai alternatif Google Forms dengan fokus pada:

1.  **Kemudahan pembuatan formulir** — form builder drag-and-drop style dengan rich text, banner, dan pengaturan yang komprehensif.
2.  **Template system** — template sistem (Blank, Attendance, Exam) dan template kustom milik pengguna yang dapat digunakan kembali.
3.  **Distribusi yang fleksibel** — berbagi via tautan slug (`/f/{slug}`) dan QR Code, serta pemindaian QR di aplikasi mobile.
4.  **Manajemen respons yang lengkap** — dashboard untuk melihat respons, skor otomatis untuk soal kuis, ekspor Excel 3 sheet, dan tampilan hasil untuk responden.

Aplikasi terdiri dari tiga bagian utama yang berbagi satu REST API:

- **Backend** — FastAPI + SQLAlchemy + PostgreSQL (juga kompatibel SQLite untuk development)
- **Web** — React + Vite + React Router + React Quill
- **Mobile** — Flutter (Android, iOS, Web, Desktop)

---

## Fitur Utama

### 1. Autentikasi dan Profil
- Registrasi dengan verifikasi OTP via email (kode 6 digit, kadaluarsa 5 menit) — `POST /auth/send-otp`, `POST /auth/signup`
- Login dengan JWT Bearer token — `POST /auth/login`
- Logout stateless dan manajemen profil (`GET /auth/me`, `PUT /auth/me`) termasuk avatar
- Mendukung identitas responden anonim via header `X-Respondent-Key` (UUID client) — seperti Google Forms, tidak wajib login untuk mengisi formulir

### 2. Form Builder (Web & Mobile)
- Pembuatan form dari kosong atau dari template (`POST /forms` dengan `template_id` atau `questions`)
- **14 tipe pertanyaan** (lihat tabel di bawah) dengan label rich-text (HTML dari Quill), placeholder, required, urutan (`order_index`), dan `settings` JSON fleksibel
- Operasi per pertanyaan: tambah, edit, hapus, duplikasi, reorder via `PATCH /questions/{id}` dan `DELETE /questions/{id}`
- Opsi jawaban per pertanyaan dengan `is_correct` (kunci jawaban) dan `is_other` (opsi "Lainnya" dengan input bebas)
- Banner form (`banner_url`), deskripsi rich-text, dan slug unik yang di-generate otomatis dari judul (sanitasi HTML)
- Pengaturan form lanjutan:
  - `status`: `draft` / `published` / `closed`
  - `accept_responses`: toggle penerimaan jawaban
  - `start_date` / `end_date`: jendela waktu pengisian (validasi zona WIB, grace 60 detik)
  - `join_token`: kode 6 karakter untuk ujian serentak
  - `allow_see_result`: responden boleh melihat skor/hasil setelah submit
  - `max_submissions`: batas jumlah submit per responden (0 = tak terbatas)
  - `require_fullscreen`: wajib fullscreen, keluar ditandai `is_cheated`
  - `reveal_answers`: tampilkan kunci jawaban di halaman hasil
- Proteksi data: jika form sudah memiliki submission, penggantian bulk `questions` ditolak dengan 409 untuk mencegah penghapusan jawaban responden

### 3. Template System
- Template sistem read-only: **Blank (Kosong)**, **Attendance (Kehadiran)**, **Exam (Ujian)** — dibuat via `python -m scripts.seed`
- Template kustom milik pengguna: `POST /templates`, `PATCH /templates/{id}`, `DELETE /templates/{id}`
- Daftar gabungan sistem + milik sendiri (`GET /templates`) dan khusus milik sendiri (`GET /templates/mine`)
- Saat membuat form dari template, pertanyaan dan opsi (termasuk `is_correct`/`is_other`) di-clone otomatis ke form baru

### 4. Pengisian Formulir dan Submission
- Akses publik form via slug: `GET /forms/public/{slug}` — validasi status, window waktu, dan `accept_responses`
- Memulai pengisian: `POST /forms/public/{slug}/join` — mengembalikan submission yang sedang berjalan atau membuat baru; validasi `join_token` jika aktif
- Autosave per jawaban: `PUT /submissions/{id}/answers` (upsert by `question_id`)
- Indikator progres: `GET /submissions/{id}/progress` → `{"answered": 3, "total": 10}`
- Submit final: `POST /submissions/{id}/submit` — validasi required, tandai `is_auto_submitted` jika lewat `end_date`
- Flag kecurangan: `POST /submissions/{id}/flag-cheated` jika keluar fullscreen
- Riwayat aktivitas responden login: `GET /submissions/me` (Aktivitas Saya)
- Hasil untuk responden: `GET /submissions/{id}/result` — skor persen, benar/salah per soal, kunci jawaban jika `reveal_answers`

### 5. Manajemen Respons (Owner Form)
- Daftar form milik sendiri dengan jumlah submission: `GET /forms`
- Daftar submission per form: `GET /forms/{form_id}/submissions` (halaman Lihat Hasil)
- Perhitungan skor, durasi pengerjaan, status selesai/proses/curang di dashboard web
- Pencarian dan filter responden (nama/email, status)

### 6. QR Code
- Generate QR dari link publik form: `POST /forms/{id}/generate-qr` → menyimpan PNG di `static/qrcodes/{slug}.png` dan mengisi `qr_code_url`
- Link publik: `{FRONTEND_URL}/f/{slug}` (mis. `https://formax-seven.vercel.app/f/form-ujian-abc123`)
- Mobile: scan QR dengan `mobile_scanner` dan buka form langsung

### 7. Upload dan Impor
- Upload file untuk pertanyaan `file_upload`: `POST /uploads` (disimpan di `static/`)
- Impor pertanyaan dari DOCX: `POST /import-docx` (via `python-docx`)
- Ekspor Excel: `GET /forms/{id}/export` menghasilkan 3 sheet (Rekap Responden, Detail Jawaban, Analisis Jawaban) dengan styling openpyxl

### 8. Fitur Web Tambahan
- Dashboard dengan 4 navigasi: Dasbor, Templat, Riwayat, Aktivitas Saya
- Pencarian global formulir/template, context menu (Edit/Hapus), drawer responsif
- Rich Text Editor berbasis `react-quill-new` dengan dukungan KaTeX, highlight.js, dan image resize
- Theme toggle (light/dark), penanganan CORS untuk Vercel preview dan ngrok tunnel

### 9. Fitur Mobile Tambahan
- Halaman: Home, History, Draft, Fill Form, Form Maker, Template Maker, Scan QR, Join Link, Result, Detail Response, Activity, Profile, Login
- Penyimpanan token dan respondent_key dengan `shared_preferences`
- Dukungan `flutter_quill`, `flutter_html`, `image_picker`, `file_picker`, `share_plus`, `url_launcher`

---

## Teknologi

| Lapisan | Teknologi | Versi / Catatan |
|---|---|---|
| **Backend** | FastAPI, Uvicorn (standard) | `0.115.0` / `0.30.6` |
| | SQLAlchemy, Psycopg2-binary | `2.0.35` / `2.9.9` |
| | Pydantic (email), Python-JOSE, Passlib + bcrypt | Validasi & JWT |
| | python-multipart, python-dotenv | Upload & env |
| | qrcode[pil], openpyxl, python-docx | QR, Excel, DOCX |
| **Web** | React, React DOM | `19.2.7` |
| | Vite, @vitejs/plugin-react | `8.1.1` / `6.0.3` |
| | React Router DOM | `7.18.2` |
| | react-quill-new, KaTeX, highlight.js | Rich text & formula |
| | @mgreminger/quill-image-resize-module | Resize gambar di editor |
| **Mobile** | Flutter (Dart SDK ^3.12.0) | `mobile/pubspec.yaml:21` |
| | mobile_scanner, image_picker, file_picker | QR scan & file |
| | flutter_quill, flutter_html, flutter_svg | Rich text & render |
| | http, shared_preferences, path_provider | Network & storage |
| | share_plus, url_launcher | Berbagi & buka tautan |
| **Database** | PostgreSQL (produksi), SQLite (dev fallback) | Auto-migrate di `app/main.py:12` |
| **Infra** | Vercel (web), ngrok tunnel (dev) | CORS regex `formax.*.vercel.app` |

---

## Arsitektur dan Diagram

Diagram tersedia di direktori `docs/`:

- `docs/flowChartForm4x.png` / `flowChartForm4x.svg` / `flowchartForm4xupdate.png` — flowchart alur aplikasi (auth → builder → publish → fill → submit → analisis)
- `docs/DFDLevel1Form4x.png` — Data Flow Diagram level 1 (entitas User, proses Form/Submission/QR, datastore)
- `docs/product_specification.md` — spesifikasi produk fase 1–5 sebagai sumber kebenaran UX

Alur tingkat tinggi:

```
[User] --register/login--> [Auth API] --JWT--> [Dashboard]
[Dashboard] --create from template/blank--> [Form Builder] --publish--> [Form (published)]
[Form (published)] --share link / QR--> [Responden (anonim/login)]
[Responden] --join--> [Submission] --autosave--> [Answers] --submit--> [Result + Export]
```

---

## Struktur Proyek

```
form-maker/
├── backend/                 # REST API — FastAPI + SQLAlchemy
│   ├── app/
│   │   ├── main.py          # Inisialisasi FastAPI, CORS, auto-migrate, mount /static
│   │   ├── database.py      # Engine & Session (DATABASE_URL)
│   │   ├── models.py        # 8 tabel: users, templates, forms, questions, question_options, submissions, answers, email_verifications
│   │   ├── schemas.py       # Pydantic schemas (request/response)
│   │   ├── security.py      # Hash password & JWT
│   │   ├── deps.py          # Dependencies: get_db, get_current_user, get_optional_user
│   │   ├── sanitize.py      # Sanitasi input
│   │   ├── routers/         # auth, templates, forms, questions, submissions, uploads, export, search, import_docx
│   │   └── utils/           # mail (OTP), helpers
│   ├── scripts/
│   │   └── seed.py          # Seed template sistem (Blank / Attendance / Exam)
│   ├── static/              # File upload & QR code (qrcodes/)
│   ├── requirements.txt
│   ├── .env.example
│   └── tests/
├── web/                     # Aplikasi Web — React + Vite
│   ├── src/
│   │   ├── api/             # Client fetch: auth, forms, templates, submissions, uploads
│   │   ├── pages/           # HomePage, AuthPage, DashboardPage, FormBuilderPage, FormFillPage, ProfilePage, TentangPage, CaraPakaiPage
│   │   ├── components/      # RichTextEditor, LandingNav, ThemeToggle, NgrokImage, InteractiveCubeBackground
│   │   ├── hooks/           # Custom hooks
│   │   ├── utils/           # date helpers, slug, dll
│   │   ├── styles/          # dashboard.css, dll
│   │   ├── App.jsx          # Routing (BrowserRouter, PrivateRoute)
│   │   └── main.jsx
│   ├── public/
│   ├── vite.config.js
│   ├── vercel.json          # Konfigurasi deploy Vercel
│   └── package.json
├── mobile/                  # Aplikasi Mobile — Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── pages/           # home, history, draft, fillform, form_maker, templatemaker, scan_qr, result, dll (14 halaman)
│   │   ├── models/          # Model Dart (form, question, submission)
│   │   ├── services/        # API service & storage
│   │   ├── widgets/         # Widget reusable
│   │   ├── theme/           # Tema & warna
│   │   └── utils/           # Helpers
│   ├── assets/              # images, icons, fonts (Schyler, Inter, OpenSans, RussoOne)
│   ├── android/ ios/ web/   # Platform-specific
│   └── pubspec.yaml
├── docs/                    # Dokumentasi & diagram
│   ├── product_specification.md
│   ├── flowChartForm4x.png
│   └── DFDLevel1Form4x.png
├── release/                 # Artefak rilis (jika ada)
└── README.md                # File ini
```

---

## Prasyarat

Pastikan perangkat telah terinstal:

| Kebutuhan | Versi Minimal | Cek Versi |
|---|---|---|
| Node.js + npm | `18+` | `node -v && npm -v` |
| Python | `3.10+` | `python --version` |
| PostgreSQL | `14+` (atau gunakan SQLite untuk dev) | `psql --version` |
| Flutter SDK | `3.12.0+` | `flutter --version` |
| Git | terbaru | `git --version` |

Untuk mobile: Android Studio / Xcode sesuai target platform.

---

## Instalasi dan Menjalankan Lokal

### 1. Clone Repositori

```bash
git clone https://github.com/<username>/form-maker.git
cd form-maker
```

### 2. Backend (FastAPI)

```bash
cd backend

# Buat virtual environment
python -m venv venv

# Aktivasi (pilih sesuai OS)
# Windows:
venv\Scripts\activate
# Linux / macOS:
source venv/bin/activate

# Instal dependensi
pip install -r requirements.txt

# Konfigurasi environment
copy .env.example .env        # Windows
# cp .env.example .env        # Linux / macOS
# Edit .env — isi DATABASE_URL dan SECRET_KEY (lihat bagian Konfigurasi)

# (Opsional) Buat database PostgreSQL jika belum ada
createdb formmaker             # atau buat manual via pgAdmin/psql

# Jalankan server
uvicorn app.main:app --reload
```

Server berjalan di `http://localhost:8000`  
Swagger UI: `http://localhost:8000/docs`  
ReDoc: `http://localhost:8000/redoc`

Isi template sistem setelah server pertama kali jalan:

```bash
python -m scripts.seed
```

> Catatan: `app/main.py:12` otomatis membuat tabel via `Base.metadata.create_all` dan menjalankan auto-migrate ringan (tambah kolom `banner_url`, `is_correct`, `is_other`, `allow_see_result`, `max_submissions`, dll). Untuk produksi, pertimbangkan migrasi dengan Alembic.

### 3. Web (React + Vite)

```bash
cd web

npm install

# Konfigurasi environment
copy .env.example .env        # Windows
# cp .env.example .env        # Linux / macOS
# Edit VITE_API_BASE_URL — default http://127.0.0.1:8000

npm run dev
```

Web berjalan di `http://localhost:5173` (Vite default). Build produksi:

```bash
npm run build
npm run preview   # pratinjau hasil build
```

### 4. Mobile (Flutter)

```bash
cd mobile

flutter pub get

# Jalankan di emulator / device terhubung
flutter run

# Build APK (Android)
flutter build apk --release

# Build untuk web
flutter build web
```

Konfigurasi base URL API di mobile ada di `lib/services/` — sesuaikan dengan `BASE_URL` backend (lokal atau ngrok).

---

## Konfigurasi Lingkungan

### Backend — `backend/.env`

Buat file `backend/.env` berdasarkan `backend/.env.example:1`:

| Variabel | Wajib | Deskripsi | Contoh |
|---|---|---|---|
| `DATABASE_URL` | Ya | URL koneksi database | `postgresql://postgres:postgres@localhost:5432/formmaker` |
| `SECRET_KEY` | Ya | Kunci rahasia untuk JWT (string acak panjang) | `ganti-dengan-random-string-panjang-dan-rahasia` |
| `BASE_URL` | Tidak | URL dasar backend (untuk QR & static) | `http://localhost:8000` |
| `FRONTEND_URL` | Tidak | URL frontend untuk generate link QR | `https://formax-seven.vercel.app` |
| `ALLOWED_ORIGINS` | Tidak | Daftar origin yang diizinkan (comma-separated). Kosong = allow all (dev/ngrok) | `https://formax-seven.vercel.app,http://localhost:5173` |
| `SMTP_*` / `MAIL_*` | Jika pakai OTP email | Konfigurasi SMTP untuk `utils/mail.py` | Lihat `app/utils/mail.py` |

Contoh `.env` lengkap:

```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/formmaker
SECRET_KEY=super-rahasia-min-32-karakter-acak
BASE_URL=http://localhost:8000
FRONTEND_URL=https://formax-seven.vercel.app
ALLOWED_ORIGINS=https://formax-seven.vercel.app,http://localhost:5173,http://localhost:3000
```

> Jika `ALLOWED_ORIGINS` diisi, CORS akan mengizinkan origin tersebut plus regex `https://formax.*.vercel.app` untuk preview deployment Vercel dan `http://localhost:*` untuk development. Jika kosong, semua origin diizinkan (`allow_origins=["*"]`) — cocok untuk ngrok tunnel.

### Web — `web/.env`

Berdasarkan `web/.env.example:1`:

| Variabel | Deskripsi | Contoh |
|---|---|---|
| `VITE_API_BASE_URL` | URL backend API tanpa trailing slash | `http://127.0.0.1:8000` atau `https://abcd-1234.ngrok-free.app` |

```env
VITE_API_BASE_URL=http://127.0.0.1:8000
```

---

## Alur Penggunaan

### A. Membuat dan Mempublikasikan Formulir (Owner)

1.  **Login / Register** — buka `/auth`, daftar dengan OTP, login untuk mendapat JWT (disimpan di `localStorage.token`)
2.  **Buka Dashboard** — `/dashboard` menampilkan Dasbor (template sistem + riwayat terbaru), Templat, Riwayat, Aktivitas Saya
3.  **Buat Form** — klik "Buat Templat Baru" atau pilih template sistem → masuk ke `/form-builder` atau `/form-builder?template={id}`
4.  **Atur Pertanyaan** — tambah/edit/hapus pertanyaan, atur tipe, opsi, required, urutan; upload banner jika perlu
5.  **Atur Setelan** — di Form Builder atur `status`, `accept_responses`, `start_date`/`end_date`, `join_token`, `allow_see_result`, `max_submissions`, `require_fullscreen`, `reveal_answers`
6.  **Simpan & Publish** — `POST /forms` atau `PATCH /forms/{id}`; untuk publish ubah status ke `published`
7.  **Bagikan** — `POST /forms/{id}/generate-qr` untuk QR, atau salin link `/f/{slug}`

### B. Mengisi Formulir (Responden)

1.  **Buka Link** — akses `/f/{slug}` atau scan QR (tidak wajib login; jika anonim, client generate `X-Respondent-Key`)
2.  **Mulai** — klik "Mulai" → `POST /forms/public/{slug}/join` (kirim `token` jika form butuh join_token) → dapat `submission_id`
3.  **Isi Jawaban** — setiap perubahan jawaban → `PUT /submissions/{id}/answers` (autosave)
4.  **Pantau Progres** — UI menampilkan progres via `GET /submissions/{id}/progress`
5.  **Submit** — `POST /submissions/{id}/submit` (validasi required; jika fullscreen aktif dan user keluar → `POST /submissions/{id}/flag-cheated`)
6.  **Lihat Hasil** (jika diizinkan) — `GET /submissions/{id}/result` menampilkan skor dan pembahasan

### C. Melihat Hasil (Owner)

1.  Buka **Riwayat** di dashboard → klik "Lihat Hasil" pada form
2.  Halaman menampilkan ringkasan (total respons, skor tertinggi/terendah) dan tabel responden dengan filter & pencarian
3.  Klik responden untuk detail jawaban
4.  **Ekspor Excel** — tombol "Ekspor ke Excel" → `GET /forms/{id}/export`

---

## Tipe Pertanyaan

Dididefinisikan di `backend/app/models.py:21` sebagai `QuestionType`:

| Tipe | Nilai Enum | Deskripsi |
|---|---|---|
| Teks Singkat | `text` | Jawaban teks satu baris |
| Paragraf | `paragraph` | Jawaban teks multi-baris |
| Pilihan Ganda | `single_choice` | Satu opsi dari banyak (radio) |
| Kotak Centang | `checkbox` | Banyak opsi (checkbox) |
| Dropdown | `dropdown` | Satu opsi via dropdown |
| Tanggal | `date` | Input tanggal |
| Waktu | `time` | Input waktu |
| Upload File | `file_upload` | Upload file (via `POST /uploads`) |
| Skala Linear | `linear_scale` | Skala numerik (mis. 1–5) |
| Rating | `rating` | Rating bintang/angka |
| Grid Pilihan Ganda | `multiple_choice_grid` | Matriks baris x kolom (satu per baris) |
| Grid Kotak Centang | `tick_box_grid` | Matriks baris x kolom (banyak per baris) |
| Pemisah Halaman | `page_break` | Section break antar halaman |
| Gambar | `image` | Tampilkan gambar di form |
| Blok Teks | `text_block` | Teks deskriptif tanpa input |

Setiap pertanyaan memiliki `is_required`, `order_index`, dan `settings` (JSON) untuk konfigurasi tambahan.

---

## Dokumentasi API

Base URL lokal: `http://localhost:8000` — dokumentasi interaktif di `/docs`

### Auth — `app/routers/auth.py:10`

| Method | Endpoint | Auth | Deskripsi |
|---|---|---|---|
| POST | `/auth/send-otp` | Tidak | Kirim OTP 6 digit ke email |
| POST | `/auth/signup` | Tidak | Daftar dengan `full_name`, `email`, `password`, `otp` → JWT |
| POST | `/auth/login` | Tidak | Login → JWT |
| POST | `/auth/logout` | Ya | Logout (instruksi hapus token client) |
| GET | `/auth/me` | Ya | Data profil sendiri |
| PUT | `/auth/me` | Ya | Update profil (`full_name`, `email`, `avatar_url`) |

### Templates — `app/routers/templates.py:10`

| Method | Endpoint | Deskripsi |
|---|---|---|
| GET | `/templates` | List template sistem + milik sendiri |
| GET | `/templates/mine` | Khusus template milik sendiri |
| POST | `/templates` | Buat template baru dengan pertanyaan & opsi |
| GET | `/templates/{id}` | Detail template |
| PATCH | `/templates/{id}` | Edit template (judul, deskripsi, pertanyaan) |
| DELETE | `/templates/{id}` | Hapus template milik sendiri |

### Forms — `app/routers/forms.py:28`

| Method | Endpoint | Deskripsi |
|---|---|---|
| GET | `/forms` | List form milik sendiri + `total_submissions` (History) |
| POST | `/forms` | Buat form (blank / dari `template_id` + `questions`) |
| GET | `/forms/{id}` | Detail form untuk owner |
| PATCH | `/forms/{id}` | Update form (bulk questions jika belum ada submission) |
| DELETE | `/forms/{id}` | Hapus form |
| POST | `/forms/{id}/publish` | Publish form (status → `published`) |
| POST | `/forms/{id}/generate-qr` | Generate QR code dari link publik |
| GET | `/forms/public/{slug}` | Akses publik form untuk diisi (validasi window & status) |
| GET | `/forms/{id}/export` | Ekspor hasil ke Excel (owner only) |

### Questions — `app/routers/questions.py`

| Method | Endpoint | Deskripsi |
|---|---|---|
| POST | `/forms/{form_id}/questions` | Tambah pertanyaan ke form |
| POST | `/templates/{template_id}/questions` | Tambah pertanyaan ke template |
| PATCH | `/questions/{id}` | Edit pertanyaan |
| DELETE | `/questions/{id}` | Hapus pertanyaan |
| POST | `/questions/{id}/options` | Tambah opsi jawaban |
| PATCH | `/options/{id}` | Edit opsi |
| DELETE | `/options/{id}` | Hapus opsi |

### Submissions — `app/routers/submissions.py:11`

| Method | Endpoint | Deskripsi |
|---|---|---|
| POST | `/forms/public/{slug}/join` | Mulai / lanjutkan pengisian (validasi token & window) |
| PUT | `/submissions/{id}/answers` | Autosave jawaban per soal |
| GET | `/submissions/{id}/progress` | Progres `answered/total` |
| POST | `/submissions/{id}/submit` | Submit final (validasi required) |
| POST | `/submissions/{id}/flag-cheated` | Tandai curang (fullscreen) |
| GET | `/submissions/me` | Daftar submission milik user login (Aktivitas Saya) |
| GET | `/submissions/{id}/result` | Hasil & skor untuk responden |
| GET | `/forms/{form_id}/submissions` | Daftar submission untuk owner |

### Lainnya

| Router | Endpoint | Deskripsi |
|---|---|---|
| Uploads | `POST /uploads` | Upload file |
| Search | `GET /search` | Pencarian form/template |
| Import DOCX | `POST /import-docx` | Impor pertanyaan dari file .docx |
| Static | `GET /static/*` | Serve file upload & QR |

---

## QR Code dan Berbagi Formulir

- **Generate:** Owner klik Generate QR di dashboard web atau mobile → `POST /forms/{id}/generate-qr` → file `static/qrcodes/{slug}.png`
- **Share Link:** `{FRONTEND_URL}/f/{slug}` — slug disanitasi dari judul (buang tag HTML) dan ditambah suffix acak 6 hex untuk keunikan
- **Scan (Mobile):** Buka `Scan QR` → `mobile_scanner` → decode → navigasi ke `FillFormPage` dengan slug
- **CORS untuk gambar:** `app/main.py:155` menambah header `Cross-Origin-Resource-Policy: cross-origin` untuk `/static` agar gambar dari ngrok/Vercel tidak terblokir

---

## Ekspor dan Analisis Respons

`GET /forms/{id}/export` menghasilkan file `{slug}-hasil.xlsx` dengan 3 sheet (`backend/app/routers/export.py:175`):

1.  **Rekap Responden** — No, Nama, Email, Waktu Mulai, Waktu Submit, Durasi, Skor /100 (jika ada soal dengan kunci), Status
2.  **Detail Jawaban** — Tiap baris adalah satu responden, tiap kolom adalah satu pertanyaan; jawaban benar ditandai `✓`, salah `✗`
3.  **Analisis Jawaban** — Per pertanyaan: distribusi opsi (jumlah & persentase) untuk tipe pilihan, atau jumlah menjawab & contoh jawaban untuk tipe teks

Styling: header biru, banding baris, auto-width, wrap text, freeze panes.

---

## Deployment

### Web (Vercel)

Konfigurasi ada di `web/vercel.json`. Set environment variable di Vercel:

- `VITE_API_BASE_URL` — URL backend produksi (mis. `https://api.form4x.example.com`)

Build command: `npm run build`, output: `dist/`

### Backend

Opsi deploy: Railway, Render, Fly.io, atau VPS dengan Docker. Pastikan:

- Set `DATABASE_URL` ke PostgreSQL produksi
- Set `SECRET_KEY` yang kuat (min 32 karakter acak)
- Set `BASE_URL` dan `FRONTEND_URL` ke domain produksi
- Set `ALLOWED_ORIGINS` ke domain Vercel dan backend
- Jalankan `python -m scripts.seed` sekali untuk template sistem
- File `static/` sebaiknya dipindah ke object storage (S3/Cloudinary) untuk produksi — lihat catatan di `backend/README.md:115`

### Mobile

Build release via `flutter build apk` / `flutter build ipa` dan distribusikan via Play Store / TestFlight atau APK langsung.

---

## Troubleshooting

| Masalah | Penyebab & Solusi |
|---|---|
| `400 Disallowed CORS origin` / gambar tidak tampil di Flutter Web | Pastikan `ALLOWED_ORIGINS` mencakup origin frontend dan `allow_origin_regex` di `app/main.py:139` sudah benar. Untuk ngrok, kosongkan `ALLOWED_ORIGINS` agar `allow_origins=["*"]`. |
| `Form belum dibuka` padahal sudah set start_date | Window dibandingkan dalam WIB (`app/routers/submissions.py:16`). Pastikan `start_date` dikirim sebagai waktu lokal browser dan server menginterpretasi dengan benar. Ada grace 60 detik. |
| `OTP tidak valid` / tidak terkirim | Cek konfigurasi SMTP di `app/utils/mail.py` dan log background task. OTP kadaluarsa 5 menit. |
| `Slug sudah dipakai` | Slug harus unik. Sistem otomatis tambah suffix hex; jika manual, gunakan hanya `a-z`, `0-9`, `-` (`app/routers/forms.py:15`). |
| `Gagal update form: sudah punya jawaban` (409) | Form dengan submission tidak boleh bulk-replace pertanyaan. Duplikasi form terlebih dahulu. |
| `is_cheated` tidak aktif | Hanya aktif jika `require_fullscreen=true`. Frontend harus kirim `POST /submissions/{id}/flag-cheated` saat `fullscreenchange` keluar. |
| Database error `column does not exist` | Jalankan ulang backend — auto-migrate di `app/main.py:24` akan menambah kolom yang hilang. Untuk perubahan besar, gunakan `create_tables.py` atau reset DB. |
| Flutter `HTTP request failed, statusCode: 0` untuk gambar | Pastikan backend mengirim `Cross-Origin-Resource-Policy: cross-origin` untuk `/static` (sudah di `app/main.py:162`) dan `ALLOWED_ORIGINS` benar. |

---

## Roadmap

Berdasarkan `docs/product_specification.md:26`:

- **Phase 1 — Core:** Auth, Home, Create/Edit Form, Questions & Options, Preview, Publish, Fill & Submit — *Selesai*
- **Phase 2 — Google Forms-like UX:** Duplicate/Delete, Drag/reorder, Required, Sections/Page Break, Images, Form Settings, Response Management — *Selesai sebagian besar*
- **Phase 3 — Template:** System Templates, My Templates, Create/Use/Edit/Delete — *Selesai*
- **Phase 4 — QR:** Generate, Display, Download, Scan & Open — *Selesai*
- **Phase 5 — Export:** Export to Excel (3 sheet) — *Selesai*
- **Next:** Notifikasi email, kolaborasi form, analitik lanjutan, migrasi Alembic, object storage, testing E2E

---

## Kontribusi

Kontribusi sangat diterima. Langkah umum:

```bash
# 1. Fork & clone
git clone https://github.com/<username>/form-maker.git
cd form-maker

# 2. Buat branch fitur
git checkout -b feat/nama-fitur

# 3. Lakukan perubahan & commit
git add .
git commit -m "feat: deskripsi singkat perubahan"

# 4. Push & buat Pull Request
git push origin feat/nama-fitur
```

Gaya commit yang disarankan: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`.

Pastikan menjalankan lint sebelum PR:

```bash
cd web && npm run lint
cd ../backend && python -m py_compile app/main.py
cd ../mobile && flutter analyze
```

---

## Lisensi

Proyek ini belum menetapkan lisensi eksplisit. Jika akan dipublikasikan, tambahkan file `LICENSE` (mis. MIT) dan cantumkan di sini.

---

Dibuat dengan fokus pada kejelasan, kecepatan, dan pengalaman pengguna yang familiar. Untuk pertanyaan atau laporan bug, buka Issue di repositori ini atau hubungi maintainer.

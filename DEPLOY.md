# Panduan Deploy Form4X ke Server Produksi (dengan SSL/HTTPS)

Ini adalah instruksi langkah demi langkah untuk mendeploy Form4X ke VPS yang sudah disiapkan SSL Nginx dan Let's Encrypt.

## Persiapan di Provider Domain (DNS)

Pastikan kamu sudah mengarahkan domain kamu ke IP VPS:
- Buat **A Record** untuk `domain.com` mengarah ke IP Server VPS kamu.
- (Opsional) Buat **A Record** untuk `www.domain.com` mengarah ke IP Server VPS kamu.
Tunggu propagasi DNS (bisa 5 menit sampai 24 jam).

## Langkah 1: Persiapkan Server VPS

Masuk ke server (SSH), install Docker & Git:

```bash
sudo apt update
sudo apt install -y git docker.io docker-compose-v2
```

Clone repositori kamu ke dalam VPS:

```bash
git clone https://github.com/USERNAME/form4xProjects.git
cd form4xProjects
```

## Langkah 2: Konfigurasi Environment

Salin file contoh ke environment asli:

```bash
cp backend/.env.example backend/.env
cp web/.env.example web/.env
```

Buka `backend/.env` dan sesuaikan nilainya:
```env
# URL Database internal docker-compose
DATABASE_URL=postgresql://postgres:GANTI_PASSWORD_KUAT@postgres:5432/formmaker

# Generate string acak panjang: openssl rand -hex 32
SECRET_KEY=masukkan-string-acak-di-sini

# Ganti dengan domain aslimu!
BASE_URL=https://domain.com/api
FRONTEND_URL=https://domain.com
ALLOWED_ORIGINS=https://domain.com
```

Buka `.env` (file di root direktori jika kamu buat untuk docker-compose) atau export DOMAIN:
```bash
export DOMAIN=domain.com
```

Pastikan juga file `docker-compose.yml` telah memiliki `POSTGRES_PASSWORD: GANTI_PASSWORD_KUAT` (sesuaikan dengan yang ada di `.env`).

## Langkah 3: Beri Izin Eksekusi Script

```bash
chmod +x init-letsencrypt.sh
```

## Langkah 4: Generate SSL Pertama Kali

Jalankan script untuk mendapatkan sertifikat dari Let's Encrypt:

```bash
# Contoh: ./init-letsencrypt.sh form4x.com email@domain.com
./init-letsencrypt.sh $DOMAIN email-admin@gmail.com
```

Script akan:
1. Membuat sertifikat dummy untuk memancing Nginx agar bisa start
2. Menjalankan Nginx
3. Meminta sertifikat asli ke Let's Encrypt dengan HTTP webroot challenge
4. Merestart Nginx secara otomatis dengan SSL yang valid.

## Langkah 5: Start Semua Service

Setelah SSL berhasil diterbitkan, jalankan sisa aplikasinya:

```bash
DOMAIN=$DOMAIN docker compose up -d --build
```

Proses ini akan memakan waktu karena akan melakukan:
- Build image Frontend (menjalankan npm run build dengan VITE_API_BASE_URL yang baru)
- Build image Backend
- Start PostgreSQL

## Langkah 6: Seed Database

Untuk pertama kalinya, jalankan script untuk mengisi database dan template awal sistem:

```bash
docker compose exec backend python -m scripts.seed
```

## Selesai! 🎉

Sekarang kamu bisa mengakses:
- **Web App**: `https://domain.com`
- **Backend API Docs**: `https://domain.com/api/docs`

> **Note**: Pembaruan sertifikat SSL otomatis ditangani oleh service `certbot` yang berjalan terus-menerus dan memeriksa pembaruan setiap 12 jam.

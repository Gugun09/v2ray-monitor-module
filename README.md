# V2Ray Monitor Module

## 📌 Overview

V2Ray Monitor Module adalah sebuah sistem monitoring sederhana untuk V2Ray yang memungkinkan pengguna untuk:

- **Memantau status V2Ray** (Running/Stopped)
- **Mengontrol V2Ray** (Start, Stop, Restart)
- **Melihat log V2Ray secara real-time**
- **Mengirim notifikasi ke Telegram** ketika terjadi perubahan status
- **Menggunakan Cloudflare Tunnel untuk akses jarak jauh**

## 🚀 Fitur Utama

- **UI berbasis web** dengan Bootstrap 5 untuk tampilan yang modern
- **Integrasi dengan Telegram Bot** untuk pemberitahuan otomatis
- **Log live monitoring** untuk melihat status terbaru
- **Support Cloudflare Tunnel** untuk akses dari luar jaringan lokal
- **Deteksi IP Lokal & IP Publik** secara otomatis

## 🛠️ Instalasi

### 1️⃣ Clone Repository

```sh
git clone https://github.com/Gugun09/v2ray_monitor_module.git
cd v2ray_monitor_module
```

### 2️⃣ Konfigurasi Environment

Buat file `.env` di `/data/local/tmp/` dengan format berikut:

```sh
TELEGRAM_BOT_TOKEN="your_bot_token"
TELEGRAM_CHAT_ID="your_chat_id"
```

### 3️⃣ Jalankan Cloudflare Tunnel *(Opsional)*

```sh
cloudflared tunnel --url http://localhost:9091 > /tmp/cloudflare_log.txt 2>&1 &
```

### 4️⃣ Jalankan UI

```sh
python3 -m http.server 9091 --bind 0.0.0.0
```

## 📡 API Endpoint

| Endpoint                            | Method | Deskripsi                            |
| ----------------------------------- | ------ | ------------------------------------ |
| `/cgi-bin/start.sh`                 | GET    | Menjalankan V2Ray                    |
| `/cgi-bin/stop.sh`                  | GET    | Menghentikan V2Ray                   |
| `/cgi-bin/restart.sh`               | GET    | Restart V2Ray                        |
| `/cgi-bin/status.sh`                | GET    | Mengecek status V2Ray                |
| `/cgi-bin/log.sh`                   | GET    | Mengambil log terbaru                |
| `/cgi-bin/update_env.sh`            | POST   | Memperbarui konfigurasi bot Telegram |
| `/cgi-bin/send_telegram_message.sh` | GET    | Mengirim pesan uji ke Telegram       |

## 📲 Notifikasi Telegram

Pesan yang dikirim ke Telegram akan berisi:

```
✅ V2Ray kembali online pada 2024-03-04 12:00:00
🌍 IP Publik: 123.456.789.000
📶 IP Lokal: 192.168.1.100
⏳ Downtime: 5 menit
🔄 Restart Hari Ini: 3 kali
--------------------------------
📡 Monitoring Koneksi
🤖 Hostname Perangkat Ini: MyDevice
🔍 Perangkat yang terhubung ke WiFi:
- 192.168.1.2 (User 1)
- 192.168.1.3 (User 2)
🌐 Akses UI: http://192.168.1.100:9091
```

## 🛑 Troubleshooting

**Masalah:** UI tidak bisa diakses dari jaringan lain **Solusi:** Pastikan server berjalan di `0.0.0.0:9091`, bukan `127.0.0.1:9091`.

**Masalah:** Bot Telegram tidak mengirim notifikasi **Solusi:** Periksa apakah token dan chat ID benar dengan `/cgi-bin/get_bot_config.sh`.

## 📜 Lisensi

Proyek ini menggunakan lisensi MIT. Silakan gunakan dan modifikasi sesuai kebutuhan.

---

🔥 **V2Ray Monitor Module** membantu kamu mengelola V2Ray dengan mudah, lengkap dengan UI dan notifikasi otomatis! 🚀

## 📥 Download v2rayNG

Untuk menjalankan V2Ray Monitor Module, Anda memerlukan aplikasi v2rayNG (Android). Silakan unduh APK versi terbaru di bawah ini:

[![Download v2rayNG](https://img.shields.io/badge/Download-v2rayNG-blue?logo=android&style=for-the-badge)](https://github.com/Gugun09/v2rayNG/releases/latest)
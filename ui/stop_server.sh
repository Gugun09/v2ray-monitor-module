#!/system/bin/sh

# Cari PID dari busybox httpd yang berjalan di port 9091
PID=$(pgrep -f "busybox httpd")

# Jika PID ditemukan, hentikan prosesnya
if [ -n "$PID" ]; then
    kill "$PID"
    echo "✅ Server UI telah dihentikan."
else
    echo "❌ Server tidak ditemukan atau sudah dihentikan."
fi

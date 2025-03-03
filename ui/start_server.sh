#!/system/bin/sh

# Pastikan busybox terpasang
if ! command -v busybox &> /dev/null; then
    echo "❌ BusyBox tidak ditemukan!"
    exit 1
fi

# Jalankan HTTP server di port 9091
busybox httpd -f -p 9091 -h /data/adb/modules/v2ray_monitor/ui/www

echo "🚀 Server UI berjalan di http://localhost:9091"
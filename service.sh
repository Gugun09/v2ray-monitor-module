#!/system/bin/sh

# File dan template .env
ENV_FILE="/data/local/tmp/.env"
ENV_TEMPLATE="/data/adb/modules/v2ray_monitor/.env-example"

# Membuat file .env jika belum ada
if [ ! -f "$ENV_FILE" ]; then
    echo "📂 Membuat file .env dari template..."
    cp "$ENV_TEMPLATE" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    sed -i 's/\r$//' "$ENV_FILE"  # Menghapus karakter carriage return pada file .env
    echo "✅ .env berhasil dibuat di $ENV_FILE"
else
    echo "✅ .env sudah ada, tidak perlu membuat ulang."
fi

# Beri izin eksekusi pada skrip
chmod +x /data/adb/modules/v2ray_monitor/ui/start_server.sh
chmod +x /data/adb/modules/v2ray_monitor/ui/stop_server.sh
chmod +x /data/adb/modules/v2ray_monitor/ui/www/cgi-bin/*

# Jalankan monitoring service hanya jika belum berjalan
if [ ! -f /data/local/tmp/v2ray_monitor.pid ]; then
    /system/xbin/v2ray_monitor_service start
fi

# Jalankan server UI hanya jika belum berjalan
if ! pgrep -f "busybox httpd.*9091" > /dev/null; then
    sh /data/adb/modules/v2ray_monitor/ui/start_server.sh &
fi

# Menunggu proses untuk memastikan semuanya berjalan
sleep 5

echo "✅ Server UI telah dimulai."
echo "🚀 Buka http://localhost:9091 untuk mengakses UI."

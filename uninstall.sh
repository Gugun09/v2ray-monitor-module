#!/system/bin/sh

echo "🗑️ Menghapus module V2Ray Monitor..."

# Hentikan skrip monitoring jika berjalan
if pgrep -f "v2ray_monitor.sh" > /dev/null; then
    echo "🛑 Menghentikan proses V2Ray Monitor..."
    pkill -f "v2ray_monitor.sh"
fi

# Hapus file konfigurasi
ENV_FILE="/data/local/tmp/.env"
if [ -f "$ENV_FILE" ]; then
    echo "🗑️ Menghapus file konfigurasi $ENV_FILE"
    rm -f "$ENV_FILE"
fi

# Hapus binary dan service
echo "🗑️ Menghapus binary & service..."
rm -f /system/xbin/v2ray_monitor.sh
rm -f /system/xbin/v2ray_monitor_service

echo "✅ Uninstall selesai!"
echo "ℹ️ Silakan reboot perangkat untuk menghapus sisa-sisa module."
#!/system/bin/sh
echo "Content-type: text/plain"
echo ""

# Panggil skrip untuk menghentikan V2Ray
/data/adb/modules/v2ray_monitor/system/xbin/v2ray_monitor.sh stop

# Bersihkan file log jika ada
LOG_FILE="/data/local/tmp/v2ray_monitor.log"
if [ -f "$LOG_FILE" ]; then
    rm -f "$LOG_FILE"
    echo "✅ Log berhasil dibersihkan!"
else
    echo "❌ Log tidak ditemukan."
fi

echo "✅ V2Ray berhasil dihentikan!"

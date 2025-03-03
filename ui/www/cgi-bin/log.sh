#!/system/bin/sh
echo "Content-type: text/plain"
echo ""

LOG_FILE="/data/local/tmp/v2ray_monitor.log"

if [ -f "$LOG_FILE" ]; then
    tail -n 30 "$LOG_FILE"  # Menampilkan 30 baris terakhir log
else
    echo "🚫 Log tidak ditemukan."
fi

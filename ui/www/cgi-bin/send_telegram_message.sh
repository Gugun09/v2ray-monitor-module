#!/system/bin/sh

# Pastikan header JSON
echo "Content-Type: application/json"
echo ""

# Source utilitas
. /data/adb/modules/v2ray_monitor/ui/www/cgi-bin/env_utils.sh
. /data/adb/modules/v2ray_monitor/ui/www/cgi-bin/telegram_utils.sh

parse_env

# Pesan yang akan dikirim
message="🔔 Tes pesan dari V2Ray Monitor"

# Kirim pesan ke Telegram
send_telegram "$message"
if [ $? -eq 0 ]; then
    echo '{"ok": true, "message": "Pesan terkirim"}'
else
    echo '{"ok": false, "error": "Gagal mengirim pesan"}'
fi

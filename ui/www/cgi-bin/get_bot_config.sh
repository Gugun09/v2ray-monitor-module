#!/system/bin/sh

# Pastikan header JSON
echo "Content-Type: application/json"
echo ""

# Pastikan file .env ada
if [[ ! -f /data/local/tmp/.env ]]; then
    echo '{"error": "File .env tidak ditemukan"}'
    exit 1
fi

# Ambil nilai dari file .env
botToken=$(grep TELEGRAM_BOT_TOKEN /data/local/tmp/.env | cut -d'=' -f2 | tr -d '"')
chatId=$(grep TELEGRAM_CHAT_ID /data/local/tmp/.env | cut -d'=' -f2 | tr -d '"')
HOSTNAME=$(getprop ro.product.model)

# Ambil URL Cloudflare Tunnel dari log
TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.[a-zA-Z]*' /tmp/cloudflare_log.txt | tail -n1)

# Periksa apakah variabel sudah terisi dengan benar
if [[ -z "$botToken" || -z "$chatId" ]]; then
    echo '{"error": "Bot Token atau Chat ID tidak ditemukan"}'
    exit 1
fi

# Format output sebagai JSON
echo "{\"botToken\": \"$botToken\", \"chatId\": \"$chatId\", \"hostname\": \"$HOSTNAME\", \"tunnelUrl\": \"$TUNNEL_URL\"}"

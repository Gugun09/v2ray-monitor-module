#!/system/bin/sh

# Pastikan header JSON
echo "Content-Type: application/json"
echo ""

# Source utilitas
. /data/adb/modules/v2ray_monitor/ui/www/cgi-bin/env_utils.sh
parse_env
HOSTNAME=$(getprop ro.product.model)

# Ambil URL Cloudflare Tunnel dari log
TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.[a-zA-Z]*' /tmp/cloudflare_log.txt | tail -n1)

# Format output sebagai JSON
echo "{\"botToken\": \"$TELEGRAM_BOT_TOKEN\", \"chatId\": \"$TELEGRAM_CHAT_ID\", \"hostname\": \"$HOSTNAME\", \"tunnelUrl\": \"$TUNNEL_URL\"}"

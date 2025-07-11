#!/system/bin/sh
# Utilitas untuk kirim pesan Telegram

ENV_FILE="/data/local/tmp/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "[telegram_utils] File .env tidak ditemukan" >&2
    exit 1
fi

TELEGRAM_BOT_TOKEN=$(grep TELEGRAM_BOT_TOKEN "$ENV_FILE" | cut -d'=' -f2 | tr -d '"')
TELEGRAM_CHAT_ID=$(grep TELEGRAM_CHAT_ID "$ENV_FILE" | cut -d'=' -f2 | tr -d '"')

send_telegram() {
    MESSAGE="$1"
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo "[telegram_utils] Bot Token atau Chat ID tidak ditemukan" >> /data/local/tmp/v2ray_monitor.log
        return 1
    fi
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$MESSAGE" > /dev/null
} 
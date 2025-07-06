#!/system/bin/sh
# Utilitas untuk parsing file .env

ENV_FILE="/data/local/tmp/.env"

parse_env() {
    if [ ! -f "$ENV_FILE" ]; then
        echo "[env_utils] File .env tidak ditemukan" >> /data/local/tmp/v2ray_monitor.log
        return 1
    fi
    export TELEGRAM_BOT_TOKEN=$(grep TELEGRAM_BOT_TOKEN "$ENV_FILE" | cut -d'=' -f2 | tr -d '"')
    export TELEGRAM_CHAT_ID=$(grep TELEGRAM_CHAT_ID "$ENV_FILE" | cut -d'=' -f2 | tr -d '"')
} 
#!/system/bin/sh

PID_FILE="/data/local/tmp/v2ray_monitor.pid"
LOG_FILE="/data/local/tmp/v2ray_monitor.log"
LAST_STATUS_FILE="/data/local/tmp/v2ray_monitor_status"
RESTART_COUNT_FILE="/data/local/tmp/v2ray_restart_count"

source /data/local/tmp/.env

HOSTNAME=$(getprop ro.product.model)
STATUS_FILE="/data/local/tmp/v2ray_status.json"

update_status_json() {
    echo "{
        \"status\": \"$1\",
        \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\",
        \"restart_count\": \"$(cat $RESTART_COUNT_FILE)\"
    }" > "$STATUS_FILE"
}

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$1" > /dev/null &
        update_status_json "Telegram notification sent"
}

get_public_ip() {
    curl -s https://api64.ipify.org || echo "Tidak diketahui"
}

get_local_ip() {
    ip -4 addr show rmnet_data4 | awk '/inet / {print $2}' | cut -d/ -f1 || echo "Tidak diketahui"
}

start() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            echo "✅ Skrip sudah berjalan dengan PID $PID."
            exit 1
        else
            rm -f "$PID_FILE"
        fi
    fi

    echo "🚀 Memulai monitoring V2Ray..."
    echo "0" > "$RESTART_COUNT_FILE"
    nohup sh "$0" monitor >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "✅ Skrip berjalan dengan PID $(cat $PID_FILE)."
}

stop() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" && rm -f "$PID_FILE"
        echo "✅ Skrip telah dihentikan."
    else
        echo "❌ Skrip tidak berjalan."
    fi
}

restart() {
    echo "🔄 Restarting skrip..."
    stop
    sleep 1
    start
}

monitor() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 Memulai monitoring V2Ray..." > "$LOG_FILE"
    LAST_STATUS=""
    RETRY_COUNT=0
    MAX_RETRY=3

    while true; do
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

        if curl --silent --fail --max-time 2 https://creativeservices.netflix.com > /dev/null 2>&1; then
            CURRENT_STATUS="VPN TERHUBUNG"
        else
            CURRENT_STATUS="VPN TIDAK TERHUBUNG"
        fi

        if [ "$CURRENT_STATUS" != "$LAST_STATUS" ]; then
            echo "[$TIMESTAMP] $CURRENT_STATUS" | tee -a "$LOG_FILE"
            echo "$CURRENT_STATUS" > "$LAST_STATUS_FILE"
            update_status_json "$CURRENT_STATUS"  # Update status in JSON

            if [ "$CURRENT_STATUS" = "VPN TERHUBUNG" ]; then
                PUBLIC_IP=$(get_public_ip)
                LOCAL_IP=$(get_local_ip)
                send_telegram "✅ V2Ray kembali online pada $TIMESTAMP.
🌍 *IP Publik*: $PUBLIC_IP
📶 *IP Lokal*: $LOCAL_IP
🔄 *Restart Hari Ini*: $(cat $RESTART_COUNT_FILE) kali
--------------------------------
📡 *Monitoring Koneksi*
🤖 *Hostname:* $HOSTNAME"
            fi

            LAST_STATUS="$CURRENT_STATUS"
        fi

        # Cek koneksi jika tidak terhubung
        if [ "$CURRENT_STATUS" = "VPN TIDAK TERHUBUNG" ]; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "[$TIMESTAMP] ❌ Koneksi gagal ($RETRY_COUNT/$MAX_RETRY). Menunggu 2 detik..." | tee -a "$LOG_FILE"
            sleep 2

            if curl --silent --fail --max-time 2 https://creativeservices.netflix.com > /dev/null 2>&1; then
                echo "[$TIMESTAMP] ✅ Koneksi kembali normal tanpa restart." | tee -a "$LOG_FILE"
                RETRY_COUNT=0
            elif [ "$RETRY_COUNT" -ge "$MAX_RETRY" ]; then
                echo "[$TIMESTAMP] 🔄 Restarting V2Ray..." | tee -a "$LOG_FILE"
                RESTART_COUNT=$(cat "$RESTART_COUNT_FILE")
                echo $((RESTART_COUNT + 1)) > "$RESTART_COUNT_FILE"
                update_status_json "Restarting V2Ray"  # Update status JSON with restart info

                su -c "am start -n com.v2ray.ang/com.v2ray.ang.ui.MainActivity"
                sleep 2
                su -c "input tap 1027 169"
                sleep 2
                su -c "input tap 648 195"

                RETRY_COUNT=0
            fi
        fi

        sleep 8
    done
}

case "$1" in
    start) start ;;
    stop) stop ;;
    restart) restart ;;
    monitor) monitor ;;
    *)
        echo "🔹 Penggunaan: $0 {start|stop|restart|monitor}"
        exit 1
        ;;
esac
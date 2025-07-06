#!/system/bin/sh

# Cek ketersediaan binary penting
for bin in curl am input awk cut head ps grep su; do
    command -v $bin >/dev/null 2>&1 || { echo "$bin tidak ditemukan!"; exit 1; }
done

# Path penting sebagai variabel global
PID_FILE="/data/local/tmp/v2ray_monitor.pid"
LOG_FILE="/data/local/tmp/v2ray_monitor.log"
LAST_STATUS_FILE="/data/local/tmp/v2ray_monitor_status"
RESTART_COUNT_FILE="/data/local/tmp/v2ray_restart_count"
HOSTNAME=$(getprop ro.product.model)

# Pastikan file penting bisa dibuat
: > "$LOG_FILE"
: > "$RESTART_COUNT_FILE"
: > "$LAST_STATUS_FILE"

# Source utilitas
. /data/adb/modules/v2ray_monitor/ui/www/cgi-bin/env_utils.sh
. /data/adb/modules/v2ray_monitor/ui/www/cgi-bin/telegram_utils.sh
parse_env

get_public_ip() {
    timeout 5 curl -s --connect-timeout 2 --max-time 3 https://api64.ipify.org || echo "Tidak diketahui"
}

get_local_ip() {
    ip -4 addr show | awk '/inet / && !/127.0.0.1/ && !/tun0/ {print $2}' | cut -d/ -f1 | head -n 1
}

# Fungsi cek status layar
is_screen_on() {
    su -c 'dumpsys power | grep "Display Power" | grep -q "state=ON"'
}

start() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            echo "✅ Skrip sudah berjalan dengan PID $PID."
            exit 1
        else
            echo "⚠️ File PID ditemukan tetapi proses tidak berjalan. Menghapus file PID..."
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
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            kill "$PID" && rm -f "$PID_FILE"
            echo "✅ Skrip telah dihentikan."
        else
            echo "⚠️ Proses dengan PID $PID tidak ditemukan. Menghapus file PID..."
            rm -f "$PID_FILE"
        fi
    else
        echo "❌ Skrip tidak berjalan."
    fi
}

restart() {
    echo "🔄 Restarting skrip..."
    stop
    sleep 2
    start
}

status() {
    if [ -f "$PID_FILE" ]; then
        echo "✅ Skrip berjalan dengan PID $(cat $PID_FILE)."
    else
        echo "❌ Skrip tidak berjalan."
    fi
}

monitor() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 Memulai monitoring V2Ray..." > "$LOG_FILE"

    LAST_STATUS=""
    DOWNTIME_START=""
    RETRY_COUNT=0
    MAX_RETRY=2
    CHECK_INTERVAL=3

    while true; do
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

        LOCAL_DEVICES=$(ip neigh show | awk '/REACHABLE/ {print $1 " (" $5 ")"}')
        GET_LOCAL_IP=$(ip -4 addr show | awk '/inet / && !/127.0.0.1/ && !/tun0/ {print $2}' | cut -d/ -f1 | head -n 1)

        # Cek koneksi menggunakan curl dengan timeout sangat singkat untuk bug VPN
        if su -c "timeout 3 curl --silent --fail --connect-timeout 1 --max-time 2 https://creativeservices.netflix.com" > /dev/null 2>&1; then
            CURRENT_STATUS="VPN TERHUBUNG"
        else
            CURRENT_STATUS="VPN TIDAK TERHUBUNG"
        fi

        # Hanya log jika status berubah
        if [ "$CURRENT_STATUS" != "$LAST_STATUS" ]; then
            echo "[$TIMESTAMP] $CURRENT_STATUS" | tee -a "$LOG_FILE"
            echo "$CURRENT_STATUS" > "$LAST_STATUS_FILE"

            # Jika VPN mati, catat waktu mulai
            if [ "$CURRENT_STATUS" = "VPN TIDAK TERHUBUNG" ]; then
                DOWNTIME_START=$(date '+%s')
                RETRY_COUNT=0  # Reset counter retry
            fi

            # Jika VPN kembali online, kirim notifikasi Telegram
            if [ "$CURRENT_STATUS" = "VPN TERHUBUNG" ]; then
                if [ -n "$DOWNTIME_START" ]; then
                    DURATION=$(( $(date '+%s') - DOWNTIME_START ))
                    DURATION_HUMAN="$(($DURATION / 3600)) jam $((($DURATION % 3600) / 60)) menit $(($DURATION % 60)) detik"
                else
                    DURATION_HUMAN="Tidak diketahui"
                fi

                PUBLIC_IP=$(get_public_ip)
                MSG="✅ V2Ray kembali online pada $TIMESTAMP.\n🌍 *IP Publik*: $PUBLIC_IP\n📶 *IP Lokal*: $GET_LOCAL_IP\n⏳ *Downtime*: $DURATION_HUMAN\n🔄 *Restart Hari Ini*: $(cat $RESTART_COUNT_FILE) kali\n--------------------------------\n📡 *Monitoring Koneksi*\n🤖 *Hostname Perangkat Ini:* $HOSTNAME\n🔍 *Perangkat yang terhubung ke WiFi:* \n$LOCAL_DEVICES\n--------------------------------\n🌐 *Akses UI*: [http://$GET_LOCAL_IP:9091](http://$GET_LOCAL_IP:9091)\n"
                if ! send_telegram "$MSG"; then
                    echo "[$TIMESTAMP] Gagal kirim notifikasi Telegram" >> "$LOG_FILE"
                fi
                DOWNTIME_START="" # Reset setelah online
            fi

            LAST_STATUS="$CURRENT_STATUS"
        fi

        # Jika tidak terhubung, lakukan retry sebelum restart
        if [ "$CURRENT_STATUS" = "VPN TIDAK TERHUBUNG" ]; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "[$TIMESTAMP] ❌ Koneksi gagal ($RETRY_COUNT/$MAX_RETRY). Menunggu $CHECK_INTERVAL detik..." | tee -a "$LOG_FILE"
            sleep $CHECK_INTERVAL

            # Cek ulang dengan timeout singkat untuk bug VPN
            if su -c "timeout 2 curl --silent --fail --connect-timeout 1 --max-time 1 https://creativeservices.netflix.com" > /dev/null 2>&1; then
                echo "[$TIMESTAMP] ✅ Koneksi kembali normal tanpa restart." | tee -a "$LOG_FILE"
                RETRY_COUNT=0  # Reset retry count
            elif [ "$RETRY_COUNT" -ge "$MAX_RETRY" ]; then
                echo "[$TIMESTAMP] 🔄 Mencoba mengaktifkan ulang V2Ray..." | tee -a "$LOG_FILE"

                # Bangunkan layar hanya jika sleep
                if ! is_screen_on; then
                    su -c "input keyevent 26"
                    sleep 1
                fi
                su -c "input keyevent 82"
                sleep 1

                RESTART_COUNT=$(cat "$RESTART_COUNT_FILE")
                echo $((RESTART_COUNT + 1)) > "$RESTART_COUNT_FILE"

                # Buka aplikasi v2rayNG
                su -c "am start -n com.v2ray.ang/com.v2ray.ang.ui.MainActivity"
                sleep 1

                # Tekan tombol untuk mengaktifkan V2Ray
                su -c "input tap 1027 169"
                sleep 1
                su -c "input tap 648 195"

                RETRY_COUNT=0  # Reset retry count setelah restart
            fi
        else
            # Jika koneksi normal, tunggu lebih lama sebelum cek berikutnya
            sleep 8
        fi
    done
}

case "$1" in
    start) start ;;
    stop) stop ;;
    restart) restart ;;
    status) status ;;
    monitor) monitor ;;
    *)
        echo "🔹 Penggunaan: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

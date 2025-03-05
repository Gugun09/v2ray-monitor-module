#!/system/bin/sh

# Variabel Telegram Bot dan Chat ID
source /data/local/tmp/.env
PID_FILE="/tmp/cloudflared.pid"

# Fungsi untuk mengirim pesan ke Telegram
send_telegram() {
    MESSAGE="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$MESSAGE" > /dev/null
}

# Fungsi untuk menghentikan tunnel
stop_tunnel() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            send_telegram "Cloudflare Tunnel telah dihentikan."
            rm -f "$PID_FILE"  # Menghapus file PID setelah menghentikan tunnel
        else
            send_telegram "Tidak ada proses tunnel yang aktif."
        fi
    else
        send_telegram "Tidak ada file PID yang ditemukan. Tunnel mungkin belum dijalankan."
    fi
}

# Fungsi untuk memulai tunnel
start_tunnel() {
    # Jalankan Cloudflare Tunnel di background dan simpan output ke file log
    /data/data/com.termux/files/usr/bin/cloudflared tunnel --url http://localhost:9091 > /tmp/cloudflare_log.txt 2>&1 &

    # Simpan PID dari cloudflared ke file
    echo $! > "$PID_FILE"

    # Tunggu beberapa detik agar tunnel dibuat
    sleep 10

    # Debug: Cek log untuk memastikan output
    echo "Log file contents:"
    cat /tmp/cloudflare_log.txt

    # Cek URL di log beberapa kali (loop 5 kali)
    for i in {1..5}; do
        TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.[a-zA-Z]*' /tmp/cloudflare_log.txt)
        if [ -n "$TUNNEL_URL" ]; then
            break
        fi
        sleep 2
    done

    # Debug output
    echo "Extracted URL: $TUNNEL_URL"

    # Mengecek apakah URL berhasil ditemukan
    if [ -n "$TUNNEL_URL" ]; then
        send_telegram "Cloudflare Tunnel URL: $TUNNEL_URL"
    else
        send_telegram "Gagal membuat Cloudflare Tunnel. Coba lagi nanti."
    fi
}

# Cek parameter untuk start atau stop
if [ "$1" == "stop" ]; then
    stop_tunnel
elif [ "$1" == "start" ]; then
    start_tunnel
else
    echo "Usage: $0 {start|stop}"
    exit 1
fi

#!/system/bin/sh

# Source utilitas
. /data/adb/modules/v2ray_monitor/ui/www/cgi-bin/env_utils.sh
. /data/adb/modules/v2ray_monitor/ui/www/cgi-bin/telegram_utils.sh

parse_env

PID_FILE="/tmp/cloudflared.pid"
CLOUDFLARED_BIN="/system/xbin/cloudflared"

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
    # Hapus log tunnel agar URL tidak tampil di web
    rm -f /tmp/cloudflare_log.txt
}

# Fungsi untuk memulai tunnel
start_tunnel() {
    if [ ! -x "$CLOUDFLARED_BIN" ]; then
        send_telegram "Cloudflare Tunnel TIDAK dijalankan karena cloudflared tidak ditemukan di $CLOUDFLARED_BIN."
        echo "cloudflared tidak ditemukan di $CLOUDFLARED_BIN, tunnel tidak dijalankan."
        exit 0
    fi
    # Jalankan Cloudflare Tunnel di background dan simpan output ke file log
    "$CLOUDFLARED_BIN" tunnel --url http://localhost:9091 > /tmp/cloudflare_log.txt 2>&1 &

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

# Support CGI (QUERY_STRING) dan argumen langsung
ACTION=""

# Cek dari argumen
if [ -n "$1" ]; then
    ACTION="$1"
# Cek dari QUERY_STRING (CGI)
elif [ -n "$QUERY_STRING" ]; then
    # Ambil parameter sebelum '=' jika ada, atau seluruh string
    ACTION=$(echo "$QUERY_STRING" | cut -d'=' -f1)
fi

if [ "$ACTION" = "stop" ]; then
    stop_tunnel
elif [ "$ACTION" = "start" ]; then
    start_tunnel
else
    echo "Usage: $0 {start|stop}"
    exit 1
fi

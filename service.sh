#!/system/bin/sh
MODDIR=${0%/*}

ENV_FILE="/data/local/tmp/.env"
ENV_TEMPLATE="$MODDIR/.env-example"

# Buat .env jika belum ada
if [ ! -f "$ENV_FILE" ]; then
    echo "📂 Membuat file .env dari template..."
    cp "$ENV_TEMPLATE" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    sed -i 's/\r$//' /data/local/tmp/.env
    echo "✅ .env berhasil dibuat di $ENV_FILE"
else
    echo "✅ .env sudah ada, tidak perlu membuat ulang."
fi

# Beri izin eksekusi ke skrip
chmod +x /system/xbin/v2ray_monitor.sh

# Tambahkan delay untuk memastikan sistem stabil
sleep 10

# Jalankan skrip monitoring di background
sh /system/xbin/v2ray_monitor.sh start &
echo "✅ Skrip monitoring V2Ray telah dimulai."
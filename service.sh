#!/system/bin/sh
MODDIR=${0%/*}

# File konfigurasi
ENV_FILE="/data/local/tmp/.env"
ENV_TEMPLATE="$MODDIR/.env-example"

# Membuat file .env jika belum ada
if [ ! -f "$ENV_FILE" ]; then
    echo "📂 Membuat file .env dari template..."
    cp "$ENV_TEMPLATE" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    sed -i 's/\r$//' "$ENV_FILE"
    echo "✅ .env berhasil dibuat di $ENV_FILE"
else
    echo "✅ .env sudah ada, tidak perlu membuat ulang."
fi

# Beri izin eksekusi pada skrip
chmod +x "$MODDIR/ui/start_server.sh"

# Delay untuk memastikan sistem stabil
sleep 10

# Jalankan server UI di background
sh "$MODDIR/ui/start_server.sh" &
if [ $? -eq 0 ]; then
    echo "✅ Server dimulai dengan sukses."
else
    echo "❌ Gagal menjalankan server."
fi

sleep 5
echo "✅ Server UI telah dimulai."
echo "🚀 Buka http://localhost:9091 untuk mengakses UI."

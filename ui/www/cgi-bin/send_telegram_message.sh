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

# Periksa apakah variabel sudah terisi
if [[ -z "$botToken" || -z "$chatId" ]]; then
    echo '{"error": "Bot Token atau Chat ID tidak ditemukan"}'
    exit 1
fi

# Pesan yang akan dikirim
message="🔔 Tes pesan dari V2Ray Monitor"

# Kirim pesan ke Telegram
response=$(curl -s -X POST "https://api.telegram.org/bot$botToken/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\": \"$chatId\", \"text\": \"$message\"}")

# Tampilkan respons dari Telegram
echo "$response"

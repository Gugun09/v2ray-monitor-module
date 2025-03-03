#!/system/bin/sh

# Pastikan header JSON
echo "Content-Type: application/json"
echo ""

# Pastikan file .env ada atau buat baru jika tidak ada
env_file="/data/local/tmp/.env"
if [[ ! -f "$env_file" ]]; then
    touch "$env_file"
fi

# Baca input JSON dari request
read input_json

# Ambil botToken dan chatId dari JSON
botToken=$(echo "$input_json" | grep -o '"botToken": *"[^"]*"' | cut -d'"' -f4)
chatId=$(echo "$input_json" | grep -o '"chatId": *"[^"]*"' | cut -d'"' -f4)

# Validasi input
if [[ -z "$botToken" || -z "$chatId" ]]; then
    echo '{"error": "Bot Token atau Chat ID tidak boleh kosong"}'
    exit 1
fi

# Update atau tambahkan konfigurasi di .env
sed -i "/^TELEGRAM_BOT_TOKEN=/d" "$env_file"
sed -i "/^TELEGRAM_CHAT_ID=/d" "$env_file"
echo "TELEGRAM_BOT_TOKEN=\"$botToken\"" >> "$env_file"
echo "TELEGRAM_CHAT_ID=\"$chatId\"" >> "$env_file"

# Konfirmasi pembaruan berhasil
echo '{"status": "success", "message": "Pengaturan Telegram berhasil diperbarui"}'
#!/system/bin/sh

# Konfigurasi variabel skrip
SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=false
LATESTARTSERVICE=true

# Direktori dan URL
MODDIR="/data/adb/modules/v2ray_monitor"
TMP_ZIP="/data/local/tmp/v2ray_monitor_module.zip"
GITHUB_URL="https://github.com/gugun09/v2ray-monitor-module/releases/latest/download/v2ray_monitor_module.zip"

ui_print "********************************************"
ui_print "  V2Ray Monitor Module Installer  "
ui_print "********************************************"

# Menampilkan instruksi pilihan
ui_print "- [ Vol UP(+): Download dan Ekstrak Modul Terbaru ]"
ui_print "- [ Vol DOWN(-): Lewati Download, Langsung Ekstrak File ZIP ]"

# Menunggu input tombol volume
START_TIME=$(date +%s)
while true; do
  NOW_TIME=$(date +%s)
  timeout 1 getevent -lc 1 2>&1 | grep KEY_VOLUME > "$TMPDIR/events"
  
  if [ $(( NOW_TIME - START_TIME )) -gt 9 ]; then
    ui_print "- Tidak ada input dalam 10 detik, melewati download dan langsung ekstrak file ZIP."
    DOWNLOAD=0
    break
  elif $(cat $TMPDIR/events | grep -q KEY_VOLUMEUP); then
    DOWNLOAD=1
    ui_print "- Memulai download modul terbaru dari GitHub..."
    break
  elif $(cat $TMPDIR/events | grep -q KEY_VOLUMEDOWN); then
    DOWNLOAD=0
    ui_print "- Mengabaikan download, langsung ekstrak file ZIP yang ada."
    break
  fi
done

# Jika tombol Volume Up ditekan, lakukan download modul terbaru dari GitHub
if [ "$DOWNLOAD" -eq 1 ]; then
  # Pastikan file ZIP tidak ada sebelumnya
  rm -f "$TMP_ZIP"
  
  ui_print "📥 Mengunduh modul terbaru dari GitHub..."
  if curl -L -o "$TMP_ZIP" "$GITHUB_URL"; then
    ui_print "✅ Unduhan selesai!"
  else
    ui_print "❌ Gagal mengunduh modul! Menggunakan file ZIP saat ini."
    DOWNLOAD=0
  fi
fi

# Siapkan direktori modul
rm -rf "$MODDIR"
mkdir -p "$MODDIR"

# Ekstrak file ZIP ke direktori modul
ui_print "📂 Mengekstrak modul..."
if [ "$DOWNLOAD" -eq 1 ]; then
  unzip -o "$TMP_ZIP" -d "$MODDIR" >&2
else
  unzip -o "$TMP_ZIP" -d "$MODDIR" >&2
fi

# Menyalin file dari sistem ke lokasi yang sesuai
ui_print "📂 Menyalin file ke direktori sistem..."
mkdir -p "$MODDIR/system/xbin"
cp "$MODDIR/system/xbin/v2ray_monitor.sh" "$MODDIR/system/xbin/v2ray_monitor_service" /system/xbin/
chmod 755 /system/xbin/v2ray_monitor.sh /system/xbin/v2ray_monitor_service

# Menyalin service.sh ke service.d (untuk dijalankan setelah boot)
SERVICE_DIR="/data/adb/service.d"
mkdir -p "$SERVICE_DIR"
cp "$MODDIR/service.sh" "$SERVICE_DIR/"

# Set izin file
ui_print "⚙️ Menyetel izin file..."
set_perm_recursive $MODDIR 0 0 0755 0644
set_perm_recursive /system/xbin 0 0 0755 0644
set_perm_recursive /data/adb/service.d 0 0 0755 0644
set_perm $SERVICE_DIR/service.sh 0 0 0755

# Menyelesaikan instalasi
ui_print "✅ Instalasi selesai!"
ui_print "🔄 Reboot untuk menerapkan perubahan."
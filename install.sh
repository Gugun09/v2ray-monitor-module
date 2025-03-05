#!/system/bin/sh

# Konfigurasi KernelSU
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

# Menampilkan pilihan input volume
ui_print "- [ Vol UP(+): Download dan Ekstrak Modul Terbaru ]"
ui_print "- [ Vol DOWN(-): Lewati Download, Langsung Ekstrak File ZIP ]"

# Menunggu input volume
START_TIME=$(date +%s)
while true; do
  NOW_TIME=$(date +%s)
  timeout 1 getevent -lc 1 2>&1 | grep KEY_VOLUME > "$TMPDIR/events"
  
  if [ $(( NOW_TIME - START_TIME )) -gt 9 ]; then
    ui_print "- Tidak ada input dalam 10 detik, langsung ekstrak file ZIP."
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

# Jika tombol Volume Up ditekan, lakukan download dari GitHub
if [ "$DOWNLOAD" -eq 1 ]; then
  rm -f "$TMP_ZIP"
  ui_print "📥 Mengunduh modul terbaru dari GitHub..."
  if curl -L -o "$TMP_ZIP" "$GITHUB_URL"; then
    ui_print "✅ Unduhan selesai!"
  else
    ui_print "❌ Gagal mengunduh modul! Menggunakan file ZIP saat ini."
    DOWNLOAD=0
  fi
fi

# Bersihkan direktori lama dan buat ulang
rm -rf "$MODDIR"
mkdir -p "$MODDIR"

# Ekstrak file ZIP ke dalam modul
ui_print "📂 Mengekstrak modul..."
unzip -o "$TMP_ZIP" -d "$MODDIR" >&2

# **PENTING**: Jangan menyalin langsung ke /system, biarkan KernelSU me-mount
ui_print "📂 Menyimpan file ke direktori modul..."
mkdir -p "$MODDIR/system/xbin"
mv "$MODDIR/v2ray_monitor.sh" "$MODDIR/system/xbin/"
mv "$MODDIR/v2ray_monitor_service" "$MODDIR/system/xbin/"
chmod 755 "$MODDIR/system/xbin/v2ray_monitor.sh" "$MODDIR/system/xbin/v2ray_monitor_service"

# Menyalin service.sh ke direktori service.d
SERVICE_DIR="/data/adb/service.d"
mkdir -p "$SERVICE_DIR"
cp "$MODDIR/service.sh" "$SERVICE_DIR/"
chmod 755 "$SERVICE_DIR/service.sh"

# Pastikan KernelSU mengenali file dengan izin yang tepat
ui_print "⚙️ Menyetel izin file..."
set_perm_recursive $MODDIR 0 0 0755 0644
set_perm $SERVICE_DIR/service.sh 0 0 0755

ui_print "✅ Instalasi selesai!"
ui_print "🔄 Reboot untuk menerapkan perubahan."

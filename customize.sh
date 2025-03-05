#!/system/bin/sh

# Direktori dan URL
MODDIR="/data/adb/modules/v2ray_monitor"
TMP_ZIP="/data/local/tmp/v2ray_monitor_module.zip"
GITHUB_URL="https://github.com/gugun09/v2ray-monitor-module/releases/latest/download/v2ray_monitor_module.zip"

ui_print "********************************************"
ui_print "  V2Ray Monitor Module Installer v1.0.0 "
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

# Ekstrak semua file langsung ke `MODDIR/`
ui_print "📂 Mengekstrak modul..."
unzip -o "$TMP_ZIP" -d "$MODDIR"

# Hapus file ZIP sementara
rm -f "$TMP_ZIP"

# Pastikan semua file memiliki izin yang benar
ui_print "⚙️ Menyetel izin file..."
set_perm_recursive $MODDIR 0 0 0755 0644

ui_print "✅ Instalasi selesai!"
ui_print "🔄 Reboot untuk menerapkan perubahan."

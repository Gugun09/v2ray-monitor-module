#!/system/bin/sh
# CGI: do_update.sh

echo "Content-Type: text/plain"
echo ""

url=$(echo "$QUERY_STRING" | sed -n 's/^url=//p')
if [ -z "$url" ]; then
    echo "URL update tidak ditemukan!"
    exit 1
fi
TMP_ZIP="/data/local/tmp/v2ray_monitor_module_update.zip"
if curl -L -o "$TMP_ZIP" "$url"; then
    unzip -o "$TMP_ZIP" -d "/data/adb/modules/v2ray_monitor"
    rm -f "$TMP_ZIP"
    echo "Update berhasil! Silakan reboot."
else
    echo "Gagal download update."
fi 
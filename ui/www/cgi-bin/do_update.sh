#!/system/bin/sh
# CGI: do_update.sh

echo "Content-Type: text/plain"
echo ""

# Debug: print QUERY_STRING ke stderr
# echo "QUERY_STRING: $QUERY_STRING" >&2

# Ambil url dari query string, decode %3A dan %2F
url=$(echo "$QUERY_STRING" | grep -oE 'url=[^&]*' | cut -d= -f2- | sed 's/%3A/:/g;s/%2F/\//g')
if [ -z "$url" ]; then
    echo "URL update tidak ditemukan!"
    exit 1
fi
if ! echo "$url" | grep -q '^http'; then
    echo "URL update tidak valid: $url"
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
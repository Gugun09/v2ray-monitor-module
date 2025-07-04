#!/system/bin/sh
# CGI: check_update.sh

echo "Content-Type: application/json"
echo ""
curl -s "https://raw.githubusercontent.com/gugun09/v2ray-monitor-module/main/update.json" 
#!/system/bin/sh

# URL file version.json di GitHub
GITHUB_URL="https://raw.githubusercontent.com/gugun09/v2ray-monitor-module/main/version.json"

# Menampilkan header JSON
echo "Content-Type: application/json"
echo ""

# Ambil langsung dari GitHub
curl -s "$GITHUB_URL"
#!/system/bin/sh
echo "Content-type: text/plain"
echo ""

case "$QUERY_STRING" in
    "action=start")
        settings put global tether_dun_required 0
        svc usb setFunctions rndis
        echo "✅ USB Tethering diaktifkan."
        ;;
    "action=stop")
        svc usb setFunctions none
        echo "❌ USB Tethering dinonaktifkan."
        ;;
    *)
        echo "❌ Gunakan parameter action=start atau action=stop"
        exit 1
        ;;
esac
# Compare this snippet from ui/www/cgi-bin/wifi_tether.sh:
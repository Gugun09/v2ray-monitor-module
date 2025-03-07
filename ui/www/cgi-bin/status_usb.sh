#!/system/bin/sh
echo "Content-type: text/plain"
echo ""

# Ambil status USB dari getprop
usb_functions=$(getprop sys.usb.config)

# Cek apakah "rndis" ada dalam hasil output
if echo "$usb_functions" | grep -q "rndis"; then
    echo "enabled"
else
    echo "disabled"
fi
# Compare this snippet from ui/www/cgi-bin/usb_tether.sh:
#!/system/bin/sh
echo "Content-type: text/plain"
echo ""
/data/adb/modules/v2ray_monitor/system/xbin/v2ray_monitor.sh restart
echo "✅ V2Ray berhasil direstart!"

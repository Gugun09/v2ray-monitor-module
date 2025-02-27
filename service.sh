#!/system/bin/sh
MODDIR=${0%/*}

# Tambahkan delay untuk memastikan sistem stabil
sleep 10

# Jalankan skrip monitoring di background
sh /system/xbin/v2ray_monitor.sh start &

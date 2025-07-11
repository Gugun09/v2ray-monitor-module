#!/system/bin/sh

# Cek status interface VPN (tun0)
VPN_ACTIVE=false
VPN_IP=""
if ip addr show tun0 2>/dev/null | grep -q "inet "; then
    VPN_ACTIVE=true
    VPN_IP=$(ip addr show tun0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
fi

# Cek proses UI v2rayNG
V2RAYNG_UI=false
V2RAYNG_UI_PID=""
V2RAYNG_UI_USER=""
if ps -A | grep -v grep | grep -q "com.v2ray.ang$"; then
    V2RAYNG_UI=true
    V2RAYNG_UI_PID=$(ps -A | grep "com.v2ray.ang$" | awk '{print $2}' | head -n1)
    V2RAYNG_UI_USER=$(ps -A | grep "com.v2ray.ang$" | awk '{print $1}' | head -n1)
fi

# Cek proses daemon v2rayNG
V2RAYNG_DAEMON=false
V2RAYNG_DAEMON_PID=""
V2RAYNG_DAEMON_USER=""
if ps -A | grep -v grep | grep -q "com.v2ray.ang:RunSoLibV2RayDaemon"; then
    V2RAYNG_DAEMON=true
    V2RAYNG_DAEMON_PID=$(ps -A | grep "com.v2ray.ang:RunSoLibV2RayDaemon" | awk '{print $2}' | head -n1)
    V2RAYNG_DAEMON_USER=$(ps -A | grep "com.v2ray.ang:RunSoLibV2RayDaemon" | awk '{print $1}' | head -n1)
fi

# Cek port SOCKS (10808) dan HTTP (10809)
SOCKS_ACTIVE=false
HTTP_ACTIVE=false
if netstat -tunlp 2>/dev/null | grep -q ":10808"; then
    SOCKS_ACTIVE=true
fi
if netstat -tunlp 2>/dev/null | grep -q ":10809"; then
    HTTP_ACTIVE=true
fi

# Cek proses v2ray binary (jika ada)
V2RAY_PROC=false
V2RAY_PROC_PID=""
V2RAY_PROC_USER=""
V2RAY_UPTIME=""
if ps -A | grep -v grep | grep -q "v2ray"; then
    V2RAY_PROC=true
    V2RAY_PROC_PID=$(ps -A | grep "v2ray" | grep -v grep | awk '{print $2}' | head -n1)
    V2RAY_PROC_USER=$(ps -A | grep "v2ray" | grep -v grep | awk '{print $1}' | head -n1)
    V2RAY_UPTIME=$(ps -A -o pid,etime,comm | grep "v2ray" | awk '{print $2}' | head -n1)
fi

# Cek versi v2ray (jika binary tersedia)
V2RAY_VERSION=""
if command -v v2ray >/dev/null 2>&1; then
    V2RAY_VERSION=$(v2ray -version 2>/dev/null | head -n1)
fi

# Output JSON detail
printf '{'
printf '"vpn":%s,' "$VPN_ACTIVE"
printf '"vpn_ip":"%s",' "$VPN_IP"
printf '"v2rayng_ui":%s,"v2rayng_ui_pid":"%s","v2rayng_ui_user":"%s",' "$V2RAYNG_UI" "$V2RAYNG_UI_PID" "$V2RAYNG_UI_USER"
printf '"v2rayng_daemon":%s,"v2rayng_daemon_pid":"%s","v2rayng_daemon_user":"%s",' "$V2RAYNG_DAEMON" "$V2RAYNG_DAEMON_PID" "$V2RAYNG_DAEMON_USER"
printf '"socks":%s,"http":%s,' "$SOCKS_ACTIVE" "$HTTP_ACTIVE"
printf '"v2ray_proc":%s,"v2ray_proc_pid":"%s","v2ray_proc_user":"%s","v2ray_uptime":"%s",' "$V2RAY_PROC" "$V2RAY_PROC_PID" "$V2RAY_PROC_USER" "$V2RAY_UPTIME"
printf '"v2ray_version":"%s"' "$V2RAY_VERSION"
printf '}\n' 
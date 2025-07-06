#!/system/bin/sh
# =============================================================================
# Status Check CGI Script - Refactored Version
# =============================================================================

echo "Content-type: text/plain"
echo ""

readonly PID_FILE="/data/local/tmp/v2ray_monitor.pid"
readonly MONITOR_SCRIPT="/data/adb/modules/v2ray_monitor/system/xbin/v2ray_monitor.sh"

# Check if monitoring script exists and is executable
if [ ! -x "$MONITOR_SCRIPT" ]; then
    echo "❌ Monitor script not found or not executable"
    exit 1
fi

# Get status from monitoring script
if command -v v2ray_monitor_service >/dev/null 2>&1; then
    v2ray_monitor_service status
else
    # Fallback to direct script execution
    "$MONITOR_SCRIPT" status
fi
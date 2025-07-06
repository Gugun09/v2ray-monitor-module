#!/system/bin/sh

# =============================================================================
# V2Ray Monitor Script - Refactored Version
# =============================================================================

# Constants
readonly SCRIPT_NAME="V2Ray Monitor"
readonly PID_FILE="/data/local/tmp/v2ray_monitor.pid"
readonly LOG_FILE="/data/local/tmp/v2ray_monitor.log"
readonly LAST_STATUS_FILE="/data/local/tmp/v2ray_monitor_status"
readonly RESTART_COUNT_FILE="/data/local/tmp/v2ray_restart_count"
readonly ENV_FILE="/data/local/tmp/.env"

# Network Configuration
readonly TARGET_URL="https://creativeservices.netflix.com"
readonly CONNECT_TIMEOUT=1
readonly MAX_TIMEOUT=2
readonly WRAPPER_TIMEOUT=3
readonly MAX_RETRY=2
readonly CHECK_INTERVAL=3
readonly NORMAL_INTERVAL=8

# Device Info
readonly HOSTNAME=$(getprop ro.product.model)

# =============================================================================
# Utility Functions
# =============================================================================

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $level: $message" | tee -a "$LOG_FILE"
}

log_info() {
    log_message "INFO" "$1"
}

log_error() {
    log_message "ERROR" "$1"
}

log_warn() {
    log_message "WARN" "$1"
}

# Check if required binaries exist
check_dependencies() {
    local missing_deps=""
    for bin in curl am input awk cut head ps grep su timeout; do
        if ! command -v "$bin" >/dev/null 2>&1; then
            missing_deps="$missing_deps $bin"
        fi
    done
    
    if [ -n "$missing_deps" ]; then
        log_error "Missing dependencies:$missing_deps"
        exit 1
    fi
}

# Initialize required files
initialize_files() {
    for file in "$LOG_FILE" "$RESTART_COUNT_FILE" "$LAST_STATUS_FILE"; do
        if [ ! -f "$file" ]; then
            : > "$file"
        fi
    done
    
    # Initialize restart count if empty
    if [ ! -s "$RESTART_COUNT_FILE" ]; then
        echo "0" > "$RESTART_COUNT_FILE"
    fi
}

# Source utilities with error handling
source_utilities() {
    local env_utils="/data/adb/modules/v2ray_monitor/ui/www/cgi-bin/env_utils.sh"
    local telegram_utils="/data/adb/modules/v2ray_monitor/ui/www/cgi-bin/telegram_utils.sh"
    
    if [ -f "$env_utils" ]; then
        . "$env_utils"
        parse_env || log_warn "Failed to parse environment variables"
    else
        log_warn "Environment utilities not found: $env_utils"
    fi
    
    if [ -f "$telegram_utils" ]; then
        . "$telegram_utils"
    else
        log_warn "Telegram utilities not found: $telegram_utils"
    fi
}

# =============================================================================
# Network Functions
# =============================================================================

get_public_ip() {
    timeout 5 curl -s --connect-timeout 2 --max-time 3 https://api64.ipify.org 2>/dev/null || echo "Tidak diketahui"
}

get_local_ip() {
    ip -4 addr show 2>/dev/null | awk '/inet / && !/127.0.0.1/ && !/tun0/ {print $2}' | cut -d/ -f1 | head -n 1
}

get_connected_devices() {
    ip neigh show 2>/dev/null | awk '/REACHABLE/ {print $1 " (" $5 ")"}'
}

# Check VPN connection using Netflix bug
check_vpn_connection() {
    su -c "timeout $WRAPPER_TIMEOUT curl --silent --fail --connect-timeout $CONNECT_TIMEOUT --max-time $MAX_TIMEOUT $TARGET_URL" >/dev/null 2>&1
}

# Quick recheck with even shorter timeout
quick_recheck_connection() {
    su -c "timeout 2 curl --silent --fail --connect-timeout 1 --max-time 1 $TARGET_URL" >/dev/null 2>&1
}

# =============================================================================
# Device Control Functions
# =============================================================================

is_screen_on() {
    local state
    state=$(su -c 'dumpsys power' | grep -E "mWakefulness=")
    echo "$state" | grep -q "mWakefulness=Awake"
}

wake_device() {
    if ! is_screen_on; then
        log_info "Waking up device screen"
        su -c "input keyevent 26" 2>/dev/null
        sleep 1
        su -c "input keyevent 82" 2>/dev/null
        sleep 1
    fi
}

restart_v2ray() {
    log_info "Attempting to restart V2Ray..."
    
    wake_device
    
    # Open v2rayNG app
    if ! su -c "am start -n com.v2ray.ang/com.v2ray.ang.ui.MainActivity" 2>/dev/null; then
        log_error "Failed to open v2rayNG app"
        return 1
    fi
    sleep 1

    # Tap to activate V2Ray
    su -c "input tap 1027 169" 2>/dev/null
    sleep 1
    su -c "input tap 648 195" 2>/dev/null
    
    # Update restart count
    local restart_count=$(cat "$RESTART_COUNT_FILE" 2>/dev/null || echo "0")
    echo $((restart_count + 1)) > "$RESTART_COUNT_FILE"
    
    log_info "V2Ray restart completed. Total restarts today: $((restart_count + 1))"
}

# =============================================================================
# Telegram Notification Functions
# =============================================================================

send_connection_restored_notification() {
    local downtime_duration="$1"
    local public_ip="$2"
    local local_ip="$3"
    local restart_count="$4"
    local connected_devices="$5"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local message="✅ V2Ray kembali online pada $timestamp.
🌍 *IP Publik*: $public_ip
📶 *IP Lokal*: $local_ip
⏳ *Downtime*: $downtime_duration
🔄 *Restart Hari Ini*: $restart_count kali
--------------------------------
📡 *Monitoring Koneksi*
🤖 *Hostname Perangkat Ini:* $HOSTNAME
🔍 *Perangkat yang terhubung ke WiFi:* 
$connected_devices
--------------------------------
🌐 *Akses UI*: [http://$local_ip:9091](http://$local_ip:9091)"

    if command -v send_telegram >/dev/null 2>&1; then
        if ! send_telegram "$message"; then
            log_error "Failed to send Telegram notification"
        fi
    else
        log_warn "Telegram function not available"
    fi
}

# =============================================================================
# Process Management Functions
# =============================================================================

is_process_running() {
    local pid="$1"
    [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1
}

get_running_pid() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE" 2>/dev/null
    fi
}

cleanup_pid_file() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(get_running_pid)
        if ! is_process_running "$pid"; then
            log_warn "PID file exists but process not running. Cleaning up..."
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 0
}

# =============================================================================
# Main Functions
# =============================================================================

start() {
    check_dependencies
    initialize_files
    
    if cleanup_pid_file; then
        local pid=$(get_running_pid)
        log_info "Script already running with PID $pid"
        exit 1
    fi

    log_info "Starting $SCRIPT_NAME..."
    echo "0" > "$RESTART_COUNT_FILE"
    
    nohup sh "$0" monitor >> "$LOG_FILE" 2>&1 & 
    echo $! > "$PID_FILE"
    log_info "Script started with PID $(cat $PID_FILE)"
}

stop() {
    local pid=$(get_running_pid)
    if [ -n "$pid" ] && is_process_running "$pid"; then
        if kill "$pid" 2>/dev/null; then
            rm -f "$PID_FILE"
            log_info "Script stopped successfully"
        else
            log_error "Failed to stop process with PID $pid"
            exit 1
        fi
    else
        cleanup_pid_file
        log_warn "Script was not running"
    fi
}

restart() {
    log_info "Restarting script..."
    stop
    sleep 2
    start
}

status() {
    local pid=$(get_running_pid)
    if [ -n "$pid" ] && is_process_running "$pid"; then
        echo "✅ Script running with PID $pid"
    else
        echo "❌ Script not running"
        cleanup_pid_file
    fi
}

# =============================================================================
# Main Monitoring Loop
# =============================================================================

monitor() {
    check_dependencies
    source_utilities
    
    log_info "Starting $SCRIPT_NAME monitoring..."

    local last_status=""
    local downtime_start=""
    local retry_count=0

    while true; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local current_status

        # Check VPN connection
        if check_vpn_connection; then
            current_status="VPN TERHUBUNG"
        else
            current_status="VPN TIDAK TERHUBUNG"
        fi

        # Handle status changes
        if [ "$current_status" != "$last_status" ]; then
            log_info "$current_status"
            echo "$current_status" > "$LAST_STATUS_FILE"

            case "$current_status" in
                "VPN TIDAK TERHUBUNG")
                    downtime_start=$(date '+%s')
                    retry_count=0
                    ;;
                "VPN TERHUBUNG")
                    if [ -n "$downtime_start" ]; then
                        local duration=$(( $(date '+%s') - downtime_start ))
                        local duration_human="$(($duration / 3600)) jam $((($duration % 3600) / 60)) menit $(($duration % 60)) detik"
                        
                        local public_ip=$(get_public_ip)
                        local local_ip=$(get_local_ip)
                        local restart_count=$(cat "$RESTART_COUNT_FILE")
                        local connected_devices=$(get_connected_devices)
                        
                        send_connection_restored_notification "$duration_human" "$public_ip" "$local_ip" "$restart_count" "$connected_devices"
                        downtime_start=""
                    fi
                    ;;
            esac
            last_status="$current_status"
        fi

        # Handle disconnection with retry logic
        if [ "$current_status" = "VPN TIDAK TERHUBUNG" ]; then
            retry_count=$((retry_count + 1))
            log_warn "Connection failed ($retry_count/$MAX_RETRY). Waiting $CHECK_INTERVAL seconds..."
            sleep $CHECK_INTERVAL

            # Quick recheck
            if quick_recheck_connection; then
                log_info "Connection restored without restart"
                retry_count=0
            elif [ "$retry_count" -ge "$MAX_RETRY" ]; then
                restart_v2ray
                retry_count=0
            fi
        else
            # Normal interval when connected
            sleep $NORMAL_INTERVAL
        fi
    done
}

# =============================================================================
# Main Script Entry Point
# =============================================================================

main() {
    case "$1" in
        start)   start ;;
        stop)    stop ;;
        restart) restart ;;
        status)  status ;;
        monitor) monitor ;;
        *)
            echo "🔹 Usage: $0 {start|stop|restart|status}"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
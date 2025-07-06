#!/system/bin/sh
# =============================================================================
# Cloudflare Tunnel Management Script - Production Ready Version
# =============================================================================

# Source utilities
. /data/adb/modules/v2ray_monitor/ui/www/cgi-bin/env_utils.sh
. /data/adb/modules/v2ray_monitor/ui/www/cgi-bin/telegram_utils.sh

parse_env

readonly PID_FILE="/tmp/cloudflared.pid"
readonly LOG_FILE="/tmp/cloudflare_log.txt"
readonly CLOUDFLARED_BIN="/system/xbin/cloudflared"

# CGI Header
echo "Content-Type: text/plain"
echo ""

# Logging function
tunnel_log() {
    echo "[tunnel] $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if tunnel process is running
is_tunnel_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
            return 0
        else
            # Clean up stale PID file
            rm -f "$PID_FILE" 2>/dev/null
        fi
    fi
    return 1
}

# Stop tunnel function
stop_tunnel() {
    tunnel_log "Stopping Cloudflare Tunnel..."
    
    if is_tunnel_running; then
        local pid=$(cat "$PID_FILE")
        if kill "$pid" 2>/dev/null; then
            rm -f "$PID_FILE"
            tunnel_log "Tunnel stopped successfully (PID: $pid)"
            
            # Send notification if Telegram is configured
            if command -v send_telegram >/dev/null 2>&1; then
                send_telegram "🛑 Cloudflare Tunnel telah dihentikan."
            fi
        else
            tunnel_log "Failed to stop tunnel process"
            echo "❌ Failed to stop tunnel process"
            return 1
        fi
    else
        tunnel_log "No tunnel process found"
        echo "⚠️ No tunnel process found"
    fi
    
    # Clean up log file
    rm -f "$LOG_FILE"
    echo "✅ Tunnel stopped successfully"
}

# Start tunnel function
start_tunnel() {
    tunnel_log "Starting Cloudflare Tunnel..."
    
    # Check if cloudflared binary exists
    if [ ! -x "$CLOUDFLARED_BIN" ]; then
        tunnel_log "Cloudflared binary not found: $CLOUDFLARED_BIN"
        echo "❌ Cloudflared not found at $CLOUDFLARED_BIN"
        
        # Send notification if Telegram is configured
        if command -v send_telegram >/dev/null 2>&1; then
            send_telegram "❌ Cloudflare Tunnel TIDAK dapat dijalankan karena cloudflared tidak ditemukan."
        fi
        return 1
    fi
    
    # Check if tunnel is already running
    if is_tunnel_running; then
        local pid=$(cat "$PID_FILE")
        tunnel_log "Tunnel already running (PID: $pid)"
        echo "⚠️ Tunnel already running"
        return 0
    fi
    
    # Start tunnel in background
    tunnel_log "Executing: $CLOUDFLARED_BIN tunnel --url http://localhost:9091"
    nohup "$CLOUDFLARED_BIN" tunnel --url http://localhost:9091 > "$LOG_FILE" 2>&1 &
    local tunnel_pid=$!
    
    # Save PID
    echo "$tunnel_pid" > "$PID_FILE"
    tunnel_log "Tunnel started with PID: $tunnel_pid"
    
    # Wait for tunnel to initialize
    echo "🔄 Starting tunnel, please wait..."
    sleep 10
    
    # Extract tunnel URL with multiple attempts
    local tunnel_url=""
    local attempts=0
    local max_attempts=5
    
    while [ $attempts -lt $max_attempts ] && [ -z "$tunnel_url" ]; do
        if [ -f "$LOG_FILE" ]; then
            tunnel_url=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.[a-zA-Z]*' "$LOG_FILE" 2>/dev/null | tail -n1)
        fi
        
        if [ -z "$tunnel_url" ]; then
            attempts=$((attempts + 1))
            tunnel_log "Attempt $attempts/$max_attempts: Waiting for tunnel URL..."
            sleep 3
        fi
    done
    
    # Check if tunnel is still running
    if ! is_tunnel_running; then
        tunnel_log "Tunnel process died unexpectedly"
        echo "❌ Tunnel failed to start"
        return 1
    fi
    
    # Report results
    if [ -n "$tunnel_url" ]; then
        tunnel_log "Tunnel URL obtained: $tunnel_url"
        echo "✅ Tunnel started successfully"
        echo "🌐 URL: $tunnel_url"
        
        # Send notification if Telegram is configured
        if command -v send_telegram >/dev/null 2>&1; then
            send_telegram "🚀 Cloudflare Tunnel berhasil dimulai!
🌐 *URL*: [$tunnel_url]($tunnel_url)
📱 *Akses*: Klik link untuk mengakses V2Ray Monitor dari mana saja"
        fi
    else
        tunnel_log "Failed to obtain tunnel URL"
        echo "⚠️ Tunnel started but URL not available yet"
        echo "📝 Check logs for more details"
        
        # Send notification if Telegram is configured
        if command -v send_telegram >/dev/null 2>&1; then
            send_telegram "⚠️ Cloudflare Tunnel dimulai tetapi URL belum tersedia. Coba lagi dalam beberapa menit."
        fi
    fi
}

# Get tunnel status
get_tunnel_status() {
    if is_tunnel_running; then
        local pid=$(cat "$PID_FILE")
        echo "✅ Tunnel running (PID: $pid)"
        
        # Try to get URL from log
        if [ -f "$LOG_FILE" ]; then
            local tunnel_url=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.[a-zA-Z]*' "$LOG_FILE" 2>/dev/null | tail -n1)
            if [ -n "$tunnel_url" ]; then
                echo "🌐 URL: $tunnel_url"
            fi
        fi
    else
        echo "❌ Tunnel not running"
    fi
}

# Main execution
main() {
    local action=""
    
    # Get action from argument or QUERY_STRING
    if [ -n "$1" ]; then
        action="$1"
    elif [ -n "$QUERY_STRING" ]; then
        action=$(echo "$QUERY_STRING" | cut -d'=' -f1)
    fi
    
    case "$action" in
        start)
            start_tunnel
            ;;
        stop)
            stop_tunnel
            ;;
        status)
            get_tunnel_status
            ;;
        *)
            echo "❌ Usage: $0 {start|stop|status}"
            echo "📝 Available actions:"
            echo "   start  - Start Cloudflare Tunnel"
            echo "   stop   - Stop Cloudflare Tunnel"
            echo "   status - Check tunnel status"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
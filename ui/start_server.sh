#!/system/bin/sh
# =============================================================================
# HTTP Server Startup Script - Refactored Version
# =============================================================================

readonly SERVER_PORT=9091
readonly DOCUMENT_ROOT="/data/adb/modules/v2ray_monitor/ui/www"
readonly PID_FILE="/tmp/httpd.pid"

# Logging function
server_log() {
    echo "[start_server] $1"
}

# Check if busybox is available
check_busybox() {
    if ! command -v busybox >/dev/null 2>&1; then
        server_log "❌ BusyBox not found! Please install BusyBox."
        exit 1
    fi
    
    # Check if httpd is available in busybox
    if ! busybox --help 2>/dev/null | grep -q httpd; then
        server_log "❌ BusyBox httpd not available!"
        exit 1
    fi
}

# Check if document root exists
check_document_root() {
    if [ ! -d "$DOCUMENT_ROOT" ]; then
        server_log "❌ Document root not found: $DOCUMENT_ROOT"
        exit 1
    fi
    
    if [ ! -f "$DOCUMENT_ROOT/index.html" ]; then
        server_log "⚠️ Warning: index.html not found in document root"
    fi
}

# Check if port is already in use
check_port() {
    if netstat -ln 2>/dev/null | grep -q ":$SERVER_PORT "; then
        server_log "⚠️ Port $SERVER_PORT is already in use"
        return 1
    fi
    return 0
}

# Stop existing server if running
stop_existing_server() {
    local existing_pid=$(pgrep -f "busybox httpd.*$SERVER_PORT")
    
    if [ -n "$existing_pid" ]; then
        server_log "Stopping existing server (PID: $existing_pid)"
        kill "$existing_pid" 2>/dev/null
        sleep 2
        
        # Force kill if still running
        if ps -p "$existing_pid" >/dev/null 2>&1; then
            kill -9 "$existing_pid" 2>/dev/null
        fi
    fi
}

# Start HTTP server
start_server() {
    server_log "Starting HTTP server on port $SERVER_PORT..."
    server_log "Document root: $DOCUMENT_ROOT"
    
    # Start server in foreground mode
    exec busybox httpd -f -p "$SERVER_PORT" -h "$DOCUMENT_ROOT"
}

# Main function
main() {
    server_log "Initializing HTTP server..."
    
    check_busybox
    check_document_root
    stop_existing_server
    
    if ! check_port; then
        server_log "❌ Port check failed, attempting to start anyway..."
    fi
    
    server_log "🚀 Starting server at http://localhost:$SERVER_PORT"
    start_server
}

# Execute main function
main "$@"
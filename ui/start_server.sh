#!/system/bin/sh
# =============================================================================
# HTTP Server Startup Script - Production Ready Version
# =============================================================================

readonly SERVER_PORT=9091
readonly DOCUMENT_ROOT="/data/adb/modules/v2ray_monitor/ui/www"
readonly PID_FILE="/tmp/httpd_v2ray_monitor.pid"
readonly LOG_FILE="/tmp/httpd_v2ray_monitor.log"

# Logging function
server_log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [start_server] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# Check if busybox is available and has httpd
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
    
    server_log "✅ BusyBox httpd available"
}

# Check if document root exists and is valid
check_document_root() {
    if [ ! -d "$DOCUMENT_ROOT" ]; then
        server_log "❌ Document root not found: $DOCUMENT_ROOT"
        exit 1
    fi
    
    if [ ! -f "$DOCUMENT_ROOT/index.html" ]; then
        server_log "⚠️ Warning: index.html not found in document root"
    fi
    
    # Check CGI directory
    if [ ! -d "$DOCUMENT_ROOT/cgi-bin" ]; then
        server_log "⚠️ Warning: cgi-bin directory not found"
    fi
    
    server_log "✅ Document root verified: $DOCUMENT_ROOT"
}

# Check if port is available
check_port() {
    if command -v netstat >/dev/null 2>&1; then
        if netstat -ln 2>/dev/null | grep -q ":$SERVER_PORT "; then
            server_log "⚠️ Port $SERVER_PORT is already in use"
            return 1
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -ln 2>/dev/null | grep -q ":$SERVER_PORT "; then
            server_log "⚠️ Port $SERVER_PORT is already in use"
            return 1
        fi
    fi
    
    server_log "✅ Port $SERVER_PORT is available"
    return 0
}

# Stop existing server if running
stop_existing_server() {
    # Check for PID file
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
            server_log "Stopping existing server (PID: $pid)"
            kill "$pid" 2>/dev/null
            sleep 2
            
            # Force kill if still running
            if ps -p "$pid" >/dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null
                server_log "Force killed server process"
            fi
        fi
        rm -f "$PID_FILE"
    fi
    
    # Check for any httpd process on our port
    local existing_pid=$(pgrep -f "busybox httpd.*$SERVER_PORT")
    if [ -n "$existing_pid" ]; then
        server_log "Found existing httpd process (PID: $existing_pid), stopping..."
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
    
    # Start server in background and capture PID
    busybox httpd -f -p "$SERVER_PORT" -h "$DOCUMENT_ROOT" >> "$LOG_FILE" 2>&1 &
    local server_pid=$!
    
    # Save PID
    echo "$server_pid" > "$PID_FILE"
    server_log "Server started with PID: $server_pid"
    
    # Wait a moment and verify it's still running
    sleep 2
    if ps -p "$server_pid" >/dev/null 2>&1; then
        server_log "✅ Server is running successfully"
        server_log "🌐 Access URL: http://localhost:$SERVER_PORT"
        
        # Try to get local IP for external access
        local local_ip=$(ip -4 addr show 2>/dev/null | awk '/inet / && !/127.0.0.1/ && !/tun0/ {print $2}' | cut -d/ -f1 | head -n 1)
        if [ -n "$local_ip" ]; then
            server_log "🌐 External access: http://$local_ip:$SERVER_PORT"
        fi
        
        # Wait for server to keep running
        wait "$server_pid"
    else
        server_log "❌ Server failed to start or died immediately"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    server_log "Received termination signal, cleaning up..."
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null
        fi
        rm -f "$PID_FILE"
    fi
    server_log "Cleanup completed"
    exit 0
}

# Set up signal handlers
trap cleanup TERM INT QUIT

# Main function
main() {
    server_log "Initializing HTTP server..."
    
    # Perform checks
    check_busybox
    check_document_root
    
    # Stop any existing server
    stop_existing_server
    
    # Check port availability (warn but continue)
    if ! check_port; then
        server_log "Port check failed, attempting to start anyway..."
    fi
    
    # Start the server
    server_log "🚀 Starting V2Ray Monitor Web Server"
    start_server
}

# Execute main function
main "$@"
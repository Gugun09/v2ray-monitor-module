#!/system/bin/sh
# =============================================================================
# V2Ray Monitor Service Initialization - Refactored Version
# =============================================================================

readonly MODULE_DIR="/data/adb/modules/v2ray_monitor"
readonly ENV_FILE="/data/local/tmp/.env"
readonly ENV_TEMPLATE="$MODULE_DIR/.env-example"
readonly PID_FILE="/data/local/tmp/v2ray_monitor.pid"

# Logging function
service_log() {
    echo "[service] $1"
}

# Create environment file if it doesn't exist
setup_environment() {
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$ENV_TEMPLATE" ]; then
            service_log "Creating environment file from template..."
            cp "$ENV_TEMPLATE" "$ENV_FILE"
            chmod 600 "$ENV_FILE"
            # Remove carriage returns if present
            sed -i 's/\r$//' "$ENV_FILE" 2>/dev/null
            service_log "Environment file created successfully: $ENV_FILE"
        else
            service_log "Warning: Template file not found: $ENV_TEMPLATE"
            # Create basic template
            cat > "$ENV_FILE" << EOF
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
EOF
            chmod 600 "$ENV_FILE"
            service_log "Basic environment file created: $ENV_FILE"
        fi
    else
        service_log "Environment file already exists: $ENV_FILE"
    fi
}

# Set proper permissions for scripts
setup_permissions() {
    service_log "Setting up file permissions..."
    
    # Main scripts
    chmod +x "$MODULE_DIR/ui/start_server.sh" 2>/dev/null
    chmod +x "$MODULE_DIR/ui/stop_server.sh" 2>/dev/null
    chmod +x "$MODULE_DIR/system/xbin/v2ray_monitor.sh" 2>/dev/null
    chmod +x "$MODULE_DIR/system/xbin/v2ray_monitor_service" 2>/dev/null
    
    # CGI scripts
    if [ -d "$MODULE_DIR/ui/www/cgi-bin" ]; then
        chmod +x "$MODULE_DIR/ui/www/cgi-bin"/* 2>/dev/null
    fi
    
    service_log "Permissions set successfully"
}

# Check if monitoring service is running
is_monitor_running() {
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

# Check if HTTP server is running
is_server_running() {
    pgrep -f "busybox httpd.*9091" >/dev/null 2>&1
}

# Start monitoring service
start_monitor() {
    if is_monitor_running; then
        service_log "V2Ray Monitor already running"
    else
        service_log "Starting V2Ray Monitor service..."
        if command -v v2ray_monitor_service >/dev/null 2>&1; then
            v2ray_monitor_service start
        else
            service_log "Warning: v2ray_monitor_service command not found"
            # Fallback to direct script execution
            if [ -x "$MODULE_DIR/system/xbin/v2ray_monitor.sh" ]; then
                "$MODULE_DIR/system/xbin/v2ray_monitor.sh" start
            fi
        fi
    fi
}

# Start HTTP server
start_server() {
    if is_server_running; then
        service_log "HTTP server already running"
    else
        service_log "Starting HTTP server..."
        if [ -x "$MODULE_DIR/ui/start_server.sh" ]; then
            sh "$MODULE_DIR/ui/start_server.sh" &
        else
            service_log "Error: start_server.sh not found or not executable"
        fi
    fi
}

# Wait for services to start
wait_for_services() {
    local max_wait=10
    local wait_count=0
    
    service_log "Waiting for services to start..."
    
    while [ $wait_count -lt $max_wait ]; do
        if is_monitor_running && is_server_running; then
            service_log "All services started successfully"
            return 0
        fi
        
        sleep 1
        wait_count=$((wait_count + 1))
    done
    
    service_log "Warning: Some services may not have started properly"
    return 1
}

# Get local IP for access information
get_local_ip() {
    ip -4 addr show 2>/dev/null | awk '/inet / && !/127.0.0.1/ && !/tun0/ {print $2}' | cut -d/ -f1 | head -n 1
}

# Main service initialization
main() {
    service_log "Initializing V2Ray Monitor Module..."
    
    # Setup environment and permissions
    setup_environment
    setup_permissions
    
    # Start services
    start_monitor
    start_server
    
    # Wait for services to be ready
    wait_for_services
    
    # Display access information
    local local_ip=$(get_local_ip)
    if [ -n "$local_ip" ]; then
        service_log "✅ V2Ray Monitor initialized successfully"
        service_log "🌐 Web UI: http://$local_ip:9091"
        service_log "🌐 Local access: http://localhost:9091"
    else
        service_log "✅ V2Ray Monitor initialized (IP detection failed)"
        service_log "🌐 Local access: http://localhost:9091"
    fi
}

# Execute main function
main "$@"
#!/system/bin/sh
# =============================================================================
# V2Ray Monitor Service Initialization - Production Ready Version
# =============================================================================

readonly MODULE_DIR="/data/adb/modules/v2ray_monitor"
readonly ENV_FILE="/data/local/tmp/.env"
readonly ENV_TEMPLATE="$MODULE_DIR/.env-example"
readonly PID_FILE="/data/local/tmp/v2ray_monitor.pid"
readonly LOG_FILE="/data/local/tmp/service_init.log"

# Logging function
service_log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [service] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# Create environment file if it doesn't exist
setup_environment() {
    service_log "Setting up environment configuration..."
    
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$ENV_TEMPLATE" ]; then
            service_log "Creating environment file from template..."
            if cp "$ENV_TEMPLATE" "$ENV_FILE"; then
                chmod 600 "$ENV_FILE"
                # Remove carriage returns if present
                sed -i 's/\r$//' "$ENV_FILE" 2>/dev/null
                service_log "Environment file created successfully: $ENV_FILE"
            else
                service_log "Failed to copy template file"
                return 1
            fi
        else
            service_log "Template file not found, creating basic environment file..."
            cat > "$ENV_FILE" << 'EOF'
# V2Ray Monitor Telegram Configuration
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
EOF
            chmod 600 "$ENV_FILE"
            service_log "Basic environment file created: $ENV_FILE"
        fi
    else
        service_log "Environment file already exists: $ENV_FILE"
    fi
    
    return 0
}

# Set proper permissions for scripts
setup_permissions() {
    service_log "Setting up file permissions..."
    
    # Main scripts
    local scripts=(
        "$MODULE_DIR/ui/start_server.sh"
        "$MODULE_DIR/ui/stop_server.sh"
        "$MODULE_DIR/system/xbin/v2ray_monitor.sh"
        "$MODULE_DIR/system/xbin/v2ray_monitor_service"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script" 2>/dev/null
            service_log "Set executable permission: $script"
        else
            service_log "Script not found: $script"
        fi
    done
    
    # CGI scripts
    if [ -d "$MODULE_DIR/ui/www/cgi-bin" ]; then
        find "$MODULE_DIR/ui/www/cgi-bin" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
        service_log "Set executable permissions for CGI scripts"
    else
        service_log "CGI directory not found: $MODULE_DIR/ui/www/cgi-bin"
    fi
    
    service_log "Permissions setup completed"
    return 0
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
            service_log "Cleaned up stale PID file"
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
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        service_log "V2Ray Monitor already running (PID: $pid)"
    else
        service_log "Starting V2Ray Monitor service..."
        
        local monitor_script="$MODULE_DIR/system/xbin/v2ray_monitor.sh"
        if [ -x "$monitor_script" ]; then
            "$monitor_script" start
            service_log "Monitor service start command executed"
        else
            service_log "Monitor script not found or not executable: $monitor_script"
            return 1
        fi
    fi
    return 0
}

# Start HTTP server
start_server() {
    if is_server_running; then
        service_log "HTTP server already running"
    else
        service_log "Starting HTTP server..."
        
        local server_script="$MODULE_DIR/ui/start_server.sh"
        if [ -x "$server_script" ]; then
            nohup sh "$server_script" >/dev/null 2>&1 &
            service_log "HTTP server start command executed"
        else
            service_log "Server script not found or not executable: $server_script"
            return 1
        fi
    fi
    return 0
}

# Wait for services to start
wait_for_services() {
    local max_wait=15
    local wait_count=0
    
    service_log "Waiting for services to start (max ${max_wait}s)..."
    
    while [ $wait_count -lt $max_wait ]; do
        local monitor_running=false
        local server_running=false
        
        if is_monitor_running; then
            monitor_running=true
        fi
        
        if is_server_running; then
            server_running=true
        fi
        
        if $monitor_running && $server_running; then
            service_log "All services started successfully"
            return 0
        fi
        
        sleep 1
        wait_count=$((wait_count + 1))
        
        # Log progress every 5 seconds
        if [ $((wait_count % 5)) -eq 0 ]; then
            service_log "Still waiting... Monitor: $monitor_running, Server: $server_running"
        fi
    done
    
    service_log "Warning: Some services may not have started properly after ${max_wait}s"
    return 1
}

# Get local IP for access information
get_local_ip() {
    # Try multiple methods to get local IP
    local ip=""
    
    # Method 1: ip command
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 addr show 2>/dev/null | awk '/inet / && !/127.0.0.1/ && !/tun0/ {print $2}' | cut -d/ -f1 | head -n 1)
    fi
    
    # Method 2: ifconfig fallback
    if [ -z "$ip" ] && command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig 2>/dev/null | awk '/inet / && !/127.0.0.1/ {print $2}' | head -n 1)
    fi
    
    # Method 3: getprop fallback for Android
    if [ -z "$ip" ] && command -v getprop >/dev/null 2>&1; then
        ip=$(getprop dhcp.wlan0.ipaddress 2>/dev/null)
    fi
    
    echo "$ip"
}

# Verify installation integrity
verify_installation() {
    service_log "Verifying installation integrity..."
    
    local required_files=(
        "$MODULE_DIR/module.prop"
        "$MODULE_DIR/service.sh"
        "$MODULE_DIR/system/xbin/v2ray_monitor.sh"
        "$MODULE_DIR/ui/www/index.html"
        "$MODULE_DIR/ui/www/js/app.js"
    )
    
    local missing_files=0
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            service_log "Missing required file: $file"
            missing_files=$((missing_files + 1))
        fi
    done
    
    if [ $missing_files -gt 0 ]; then
        service_log "Installation verification failed: $missing_files missing files"
        return 1
    fi
    
    service_log "Installation verification passed"
    return 0
}

# Main service initialization
main() {
    service_log "Initializing V2Ray Monitor Module..."
    
    # Verify installation
    if ! verify_installation; then
        service_log "Installation verification failed, aborting initialization"
        exit 1
    fi
    
    # Setup environment and permissions
    if ! setup_environment; then
        service_log "Environment setup failed"
        exit 1
    fi
    
    if ! setup_permissions; then
        service_log "Permission setup failed"
        exit 1
    fi
    
    # Start services
    if ! start_monitor; then
        service_log "Failed to start monitor service"
    fi
    
    if ! start_server; then
        service_log "Failed to start HTTP server"
    fi
    
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
    
    # Final status check
    if is_monitor_running && is_server_running; then
        service_log "All services are running successfully"
        exit 0
    else
        service_log "Some services may not be running properly"
        exit 1
    fi
}

# Execute main function
main "$@"
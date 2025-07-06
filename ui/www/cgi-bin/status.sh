#!/system/bin/sh
# =============================================================================
# Status Check CGI Script - Production Ready Version
# =============================================================================

echo "Content-type: text/plain"
echo ""

readonly PID_FILE="/data/local/tmp/v2ray_monitor.pid"
readonly MONITOR_SCRIPT="/data/adb/modules/v2ray_monitor/system/xbin/v2ray_monitor.sh"
readonly SERVICE_COMMAND="/data/adb/modules/v2ray_monitor/system/xbin/v2ray_monitor_service"

# Function to check if process is running
is_process_running() {
    local pid="$1"
    [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1
}

# Function to get PID from file
get_pid_from_file() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE" 2>/dev/null
    fi
}

# Function to check monitor status
check_monitor_status() {
    local pid=$(get_pid_from_file)
    
    if [ -n "$pid" ] && is_process_running "$pid"; then
        echo "✅ V2Ray Monitor is running (PID: $pid)"
        
        # Additional status information
        local uptime_seconds=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -n "$uptime_seconds" ]; then
            echo "⏱️  Process uptime: $uptime_seconds"
        fi
        
        # Check if log file exists and get last entry
        local log_file="/data/local/tmp/v2ray_monitor.log"
        if [ -f "$log_file" ] && [ -s "$log_file" ]; then
            local last_log=$(tail -n 1 "$log_file" 2>/dev/null)
            if [ -n "$last_log" ]; then
                echo "📝 Last log: $last_log"
            fi
        fi
        
        return 0
    else
        echo "❌ V2Ray Monitor is not running"
        
        # Clean up stale PID file
        if [ -f "$PID_FILE" ]; then
            rm -f "$PID_FILE" 2>/dev/null
            echo "🧹 Cleaned up stale PID file"
        fi
        
        return 1
    fi
}

# Function to check system dependencies
check_dependencies() {
    local missing_deps=""
    local required_commands="curl su am input ps grep"
    
    for cmd in $required_commands; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps="$missing_deps $cmd"
        fi
    done
    
    if [ -n "$missing_deps" ]; then
        echo "⚠️  Missing dependencies:$missing_deps"
        return 1
    fi
    
    return 0
}

# Function to check script files
check_script_files() {
    local issues=""
    
    if [ ! -f "$MONITOR_SCRIPT" ]; then
        issues="$issues\n❌ Monitor script not found: $MONITOR_SCRIPT"
    elif [ ! -x "$MONITOR_SCRIPT" ]; then
        issues="$issues\n⚠️  Monitor script not executable: $MONITOR_SCRIPT"
    fi
    
    if [ ! -f "$SERVICE_COMMAND" ]; then
        issues="$issues\n❌ Service command not found: $SERVICE_COMMAND"
    elif [ ! -x "$SERVICE_COMMAND" ]; then
        issues="$issues\n⚠️  Service command not executable: $SERVICE_COMMAND"
    fi
    
    if [ -n "$issues" ]; then
        echo -e "$issues"
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    # Check if this is a detailed status request
    if [ -n "$QUERY_STRING" ] && echo "$QUERY_STRING" | grep -q 'detailed=1'; then
        echo "🔍 Detailed Status Report"
        echo "========================"
        echo ""
        
        # Check dependencies
        echo "📋 System Dependencies:"
        if check_dependencies; then
            echo "✅ All required commands available"
        fi
        echo ""
        
        # Check script files
        echo "📁 Script Files:"
        if check_script_files; then
            echo "✅ All script files present and executable"
        fi
        echo ""
        
        # Check monitor status
        echo "🔄 Monitor Status:"
        check_monitor_status
        echo ""
        
        # Check HTTP server
        echo "🌐 HTTP Server:"
        if pgrep -f "busybox httpd.*9091" >/dev/null 2>&1; then
            echo "✅ HTTP server is running on port 9091"
        else
            echo "❌ HTTP server is not running"
        fi
        echo ""
        
        # Check environment file
        echo "⚙️  Configuration:"
        local env_file="/data/local/tmp/.env"
        if [ -f "$env_file" ]; then
            echo "✅ Environment file exists: $env_file"
            if [ -r "$env_file" ]; then
                local bot_token=$(grep "^TELEGRAM_BOT_TOKEN=" "$env_file" 2>/dev/null | cut -d= -f2 | tr -d '"')
                local chat_id=$(grep "^TELEGRAM_CHAT_ID=" "$env_file" 2>/dev/null | cut -d= -f2 | tr -d '"')
                
                if [ -n "$bot_token" ] && [ -n "$chat_id" ]; then
                    echo "✅ Telegram configuration present"
                else
                    echo "⚠️  Telegram configuration incomplete"
                fi
            else
                echo "❌ Environment file not readable"
            fi
        else
            echo "❌ Environment file not found"
        fi
        
        return 0
    fi
    
    # Standard status check
    if check_script_files; then
        check_monitor_status
    else
        echo "❌ System configuration error"
        exit 1
    fi
}

# Execute main function
main "$@"
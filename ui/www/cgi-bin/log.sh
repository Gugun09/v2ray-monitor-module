#!/system/bin/sh
# =============================================================================
# Log Display CGI Script - Refactored Version
# =============================================================================

echo "Content-type: text/plain"
echo ""

readonly LOG_FILE="/data/local/tmp/v2ray_monitor.log"
readonly DEFAULT_LINES=30

# Function to display log with error handling
display_log() {
    local lines="${1:-$DEFAULT_LINES}"
    
    if [ ! -f "$LOG_FILE" ]; then
        echo "🚫 Log file not found: $LOG_FILE"
        return 1
    fi
    
    if [ ! -r "$LOG_FILE" ]; then
        echo "🚫 Log file not readable: $LOG_FILE"
        return 1
    fi
    
    # Check if file is empty
    if [ ! -s "$LOG_FILE" ]; then
        echo "📝 Log file is empty"
        return 0
    fi
    
    # Display last N lines
    if command -v tail >/dev/null 2>&1; then
        tail -n "$lines" "$LOG_FILE" 2>/dev/null || {
            echo "🚫 Error reading log file"
            return 1
        }
    else
        echo "🚫 'tail' command not available"
        return 1
    fi
}

# Parse query parameters for custom line count
if [ -n "$QUERY_STRING" ]; then
    lines=$(echo "$QUERY_STRING" | grep -o 'lines=[0-9]*' | cut -d= -f2)
    if [ -n "$lines" ] && [ "$lines" -gt 0 ] && [ "$lines" -le 1000 ]; then
        display_log "$lines"
    else
        display_log
    fi
else
    display_log
fi
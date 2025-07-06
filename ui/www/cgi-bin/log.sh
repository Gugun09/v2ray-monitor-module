#!/system/bin/sh
# =============================================================================
# Log Display CGI Script - Production Ready Version
# =============================================================================

echo "Content-type: text/plain"
echo ""

readonly LOG_FILE="/data/local/tmp/v2ray_monitor.log"
readonly DEFAULT_LINES=50
readonly MAX_LINES=1000

# Function to safely get numeric parameter
get_numeric_param() {
    local value="$1"
    local default="$2"
    local max="$3"
    
    # Check if value is numeric
    if echo "$value" | grep -q '^[0-9]\+$'; then
        # Ensure it's within bounds
        if [ "$value" -gt "$max" ]; then
            echo "$max"
        elif [ "$value" -lt 1 ]; then
            echo "$default"
        else
            echo "$value"
        fi
    else
        echo "$default"
    fi
}

# Function to display log with error handling
display_log() {
    local lines="$1"
    
    if [ ! -f "$LOG_FILE" ]; then
        echo "📝 Log file not found: $LOG_FILE"
        echo "ℹ️  This is normal if the monitor hasn't been started yet."
        return 0
    fi
    
    if [ ! -r "$LOG_FILE" ]; then
        echo "🚫 Log file not readable: $LOG_FILE"
        echo "❌ Permission denied. Check file permissions."
        return 1
    fi
    
    # Check if file is empty
    if [ ! -s "$LOG_FILE" ]; then
        echo "📝 Log file is empty"
        echo "ℹ️  No log entries available yet."
        return 0
    fi
    
    # Display last N lines with error handling
    if command -v tail >/dev/null 2>&1; then
        if ! tail -n "$lines" "$LOG_FILE" 2>/dev/null; then
            echo "🚫 Error reading log file"
            echo "❌ Failed to read log contents."
            return 1
        fi
    else
        echo "🚫 'tail' command not available"
        echo "❌ System utility missing."
        return 1
    fi
}

# Parse query parameters
lines="$DEFAULT_LINES"

if [ -n "$QUERY_STRING" ]; then
    # Extract lines parameter
    query_lines=$(echo "$QUERY_STRING" | grep -o 'lines=[0-9]*' | cut -d= -f2)
    if [ -n "$query_lines" ]; then
        lines=$(get_numeric_param "$query_lines" "$DEFAULT_LINES" "$MAX_LINES")
    fi
    
    # Check for other parameters
    if echo "$QUERY_STRING" | grep -q 'clear=1'; then
        echo "🗑️ Log clear requested"
        echo "⚠️  Use the clear button in the web interface to clear logs."
        exit 0
    fi
    
    if echo "$QUERY_STRING" | grep -q 'info=1'; then
        echo "📊 Log Information"
        echo "📁 File: $LOG_FILE"
        if [ -f "$LOG_FILE" ]; then
            echo "📏 Size: $(wc -c < "$LOG_FILE" 2>/dev/null || echo "unknown") bytes"
            echo "📄 Lines: $(wc -l < "$LOG_FILE" 2>/dev/null || echo "unknown")"
            echo "🕒 Modified: $(ls -l "$LOG_FILE" 2>/dev/null | awk '{print $6, $7, $8}' || echo "unknown")"
        else
            echo "❌ File does not exist"
        fi
        exit 0
    fi
fi

# Display the log
display_log "$lines"
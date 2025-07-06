#!/system/bin/sh
# =============================================================================
# Telegram Utilities - Refactored Version
# =============================================================================

readonly TELEGRAM_API_BASE="https://api.telegram.org/bot"
readonly TELEGRAM_TIMEOUT=10

# Logging function for telegram_utils
telegram_log() {
    echo "[telegram_utils] $1" >&2
}

# Validate Telegram configuration
validate_telegram_config() {
    if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        telegram_log "Bot token not configured"
        return 1
    fi
    
    if [ -z "$TELEGRAM_CHAT_ID" ]; then
        telegram_log "Chat ID not configured"
        return 1
    fi
    
    # Basic token format validation (should start with digits followed by colon)
    if ! echo "$TELEGRAM_BOT_TOKEN" | grep -q '^[0-9]\+:'; then
        telegram_log "Invalid bot token format"
        return 1
    fi
    
    return 0
}

# Send message to Telegram with error handling and retry
send_telegram() {
    local message="$1"
    local max_retries=3
    local retry_count=0
    
    if [ -z "$message" ]; then
        telegram_log "Empty message provided"
        return 1
    fi
    
    if ! validate_telegram_config; then
        return 1
    fi
    
    # Escape special characters for URL encoding
    local encoded_message=$(echo "$message" | sed 's/ /%20/g; s/\n/%0A/g')
    local api_url="${TELEGRAM_API_BASE}${TELEGRAM_BOT_TOKEN}/sendMessage"
    
    while [ $retry_count -lt $max_retries ]; do
        telegram_log "Sending message (attempt $((retry_count + 1))/$max_retries)"
        
        local response=$(curl -s --connect-timeout 5 --max-time $TELEGRAM_TIMEOUT \
            -X POST "$api_url" \
            -d "chat_id=$TELEGRAM_CHAT_ID" \
            -d "text=$encoded_message" \
            -d "parse_mode=Markdown" \
            2>/dev/null)
        
        if [ $? -eq 0 ] && echo "$response" | grep -q '"ok":true'; then
            telegram_log "Message sent successfully"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            telegram_log "Failed to send message, retrying in 2 seconds..."
            sleep 2
        fi
    done
    
    telegram_log "Failed to send message after $max_retries attempts"
    return 1
}

# Test Telegram configuration by sending a test message
test_telegram_config() {
    local test_message="🔔 Test message from V2Ray Monitor - Configuration is working!"
    
    if send_telegram "$test_message"; then
        telegram_log "Telegram configuration test successful"
        return 0
    else
        telegram_log "Telegram configuration test failed"
        return 1
    fi
}

# Get bot information for validation
get_bot_info() {
    if ! validate_telegram_config; then
        return 1
    fi
    
    local api_url="${TELEGRAM_API_BASE}${TELEGRAM_BOT_TOKEN}/getMe"
    
    curl -s --connect-timeout 5 --max-time $TELEGRAM_TIMEOUT "$api_url" 2>/dev/null
}
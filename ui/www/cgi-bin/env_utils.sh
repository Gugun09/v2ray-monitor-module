#!/system/bin/sh
# =============================================================================
# Environment Utilities - Production Ready Version
# =============================================================================

readonly ENV_FILE="/data/local/tmp/.env"

# Logging function for env_utils
env_log() {
    echo "[env_utils] $1" >&2
}

# Validate environment file exists and is readable
validate_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        env_log "Environment file not found: $ENV_FILE"
        return 1
    fi
    
    if [ ! -r "$ENV_FILE" ]; then
        env_log "Environment file not readable: $ENV_FILE"
        return 1
    fi
    
    return 0
}

# Extract value from environment file with validation
extract_env_value() {
    local key="$1"
    local value
    
    if ! validate_env_file; then
        return 1
    fi
    
    # Extract value and remove quotes, handle both single and double quotes
    value=$(grep "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | sed 's/^["'\'']*//;s/["'\'']*$//')
    
    if [ -z "$value" ]; then
        env_log "Empty or missing value for $key"
        return 1
    fi
    
    echo "$value"
    return 0
}

# Parse environment variables with error handling
parse_env() {
    if ! validate_env_file; then
        return 1
    fi
    
    # Extract Telegram configuration
    TELEGRAM_BOT_TOKEN=$(extract_env_value "TELEGRAM_BOT_TOKEN")
    TELEGRAM_CHAT_ID=$(extract_env_value "TELEGRAM_CHAT_ID")
    
    # Export variables if successfully extracted
    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        export TELEGRAM_BOT_TOKEN
    else
        env_log "Failed to extract TELEGRAM_BOT_TOKEN"
    fi
    
    if [ -n "$TELEGRAM_CHAT_ID" ]; then
        export TELEGRAM_CHAT_ID
    else
        env_log "Failed to extract TELEGRAM_CHAT_ID"
    fi
    
    # Return success if at least one variable was set
    if [ -n "$TELEGRAM_BOT_TOKEN" ] || [ -n "$TELEGRAM_CHAT_ID" ]; then
        return 0
    else
        env_log "No valid environment variables found"
        return 1
    fi
}

# Check if Telegram configuration is complete
is_telegram_configured() {
    [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]
}

# Create environment file from template if it doesn't exist
create_env_from_template() {
    local template_file="/data/adb/modules/v2ray_monitor/.env-example"
    
    if [ ! -f "$ENV_FILE" ] && [ -f "$template_file" ]; then
        env_log "Creating environment file from template"
        cp "$template_file" "$ENV_FILE"
        chmod 600 "$ENV_FILE"
        # Remove carriage returns if present
        sed -i 's/\r$//' "$ENV_FILE" 2>/dev/null
        return 0
    fi
    
    return 1
}
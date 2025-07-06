#!/system/bin/sh
# =============================================================================
# Environment Configuration Update Script - Production Ready Version
# =============================================================================

# CGI Headers
echo "Content-Type: application/json"
echo ""

readonly ENV_FILE="/data/local/tmp/.env"

# Source utilities
. /data/adb/modules/v2ray_monitor/ui/www/cgi-bin/env_utils.sh

# Logging function
update_log() {
    echo "[update_env] $1" >&2
}

# Validate JSON input
validate_json_input() {
    local input="$1"
    
    if [ -z "$input" ]; then
        echo '{"error": "No input data received"}'
        exit 1
    fi
    
    # Basic JSON validation - check for required fields
    if ! echo "$input" | grep -q '"botToken"' || ! echo "$input" | grep -q '"chatId"'; then
        echo '{"error": "Missing required fields: botToken or chatId"}'
        exit 1
    fi
}

# Extract JSON values safely
extract_json_value() {
    local json="$1"
    local key="$2"
    
    # Extract value between quotes, handle escaped quotes
    echo "$json" | grep -o "\"$key\": *\"[^\"]*\"" | cut -d'"' -f4
}

# Validate bot token format
validate_bot_token() {
    local token="$1"
    
    if [ -z "$token" ]; then
        return 1
    fi
    
    # Bot token should be in format: digits:alphanumeric
    if ! echo "$token" | grep -q '^[0-9]\+:[A-Za-z0-9_-]\+$'; then
        return 1
    fi
    
    return 0
}

# Validate chat ID format
validate_chat_id() {
    local chat_id="$1"
    
    if [ -z "$chat_id" ]; then
        return 1
    fi
    
    # Chat ID should be numeric (positive or negative)
    if ! echo "$chat_id" | grep -q '^-\?[0-9]\+$'; then
        return 1
    fi
    
    return 0
}

# Create backup of existing env file
backup_env_file() {
    if [ -f "$ENV_FILE" ]; then
        local backup_file="${ENV_FILE}.backup.$(date +%s)"
        cp "$ENV_FILE" "$backup_file" 2>/dev/null
        update_log "Created backup: $backup_file"
    fi
}

# Update environment file safely
update_env_file() {
    local bot_token="$1"
    local chat_id="$2"
    
    # Create temporary file
    local temp_file="${ENV_FILE}.tmp"
    
    # Create new env file content
    {
        echo "# V2Ray Monitor Telegram Configuration"
        echo "# Generated on $(date)"
        echo "TELEGRAM_BOT_TOKEN=\"$bot_token\""
        echo "TELEGRAM_CHAT_ID=\"$chat_id\""
    } > "$temp_file"
    
    # Verify temp file was created successfully
    if [ ! -f "$temp_file" ]; then
        echo '{"error": "Failed to create temporary configuration file"}'
        exit 1
    fi
    
    # Atomic move
    if mv "$temp_file" "$ENV_FILE"; then
        chmod 600 "$ENV_FILE"
        update_log "Environment file updated successfully"
        return 0
    else
        rm -f "$temp_file" 2>/dev/null
        echo '{"error": "Failed to update configuration file"}'
        exit 1
    fi
}

# Main execution
main() {
    update_log "Processing environment update request"
    
    # Ensure env file directory exists
    mkdir -p "$(dirname "$ENV_FILE")" 2>/dev/null
    
    # Read JSON input
    local input_json
    if ! input_json=$(cat); then
        echo '{"error": "Failed to read input data"}'
        exit 1
    fi
    
    update_log "Received input: ${#input_json} characters"
    
    # Validate input
    validate_json_input "$input_json"
    
    # Extract values
    local bot_token=$(extract_json_value "$input_json" "botToken")
    local chat_id=$(extract_json_value "$input_json" "chatId")
    
    update_log "Extracted botToken length: ${#bot_token}"
    update_log "Extracted chatId: $chat_id"
    
    # Validate extracted values
    if ! validate_bot_token "$bot_token"; then
        echo '{"error": "Invalid bot token format. Expected format: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"}'
        exit 1
    fi
    
    if ! validate_chat_id "$chat_id"; then
        echo '{"error": "Invalid chat ID format. Expected numeric value (e.g., 123456789 or -123456789)"}'
        exit 1
    fi
    
    # Create backup before updating
    backup_env_file
    
    # Update environment file
    if update_env_file "$bot_token" "$chat_id"; then
        echo '{"status": "success", "message": "Telegram configuration updated successfully"}'
        update_log "Configuration update completed successfully"
    else
        echo '{"error": "Failed to update configuration"}'
        exit 1
    fi
}

# Execute main function
main "$@"
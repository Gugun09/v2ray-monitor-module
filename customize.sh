#!/system/bin/sh
# =============================================================================
# V2Ray Monitor Module Installer - Production Ready Version
# =============================================================================

readonly MODDIR="/data/adb/modules/v2ray_monitor"
readonly TMP_ZIP="/data/local/tmp/v2ray_monitor_module.zip"
readonly GITHUB_URL="https://github.com/gugun09/v2ray-monitor-module/releases/latest/download/v2ray_monitor_module.zip"
readonly LOG_FILE="/data/local/tmp/v2ray_monitor_install.log"
readonly TIMEOUT_SECONDS=10

# Logging function
install_log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [installer] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# UI print with logging
ui_print() {
    echo "$1"
    install_log "$1"
}

# Check if required commands are available
check_dependencies() {
    local missing_deps=""
    local required_commands="curl unzip chmod"
    
    for cmd in $required_commands; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps="$missing_deps $cmd"
        fi
    done
    
    if [ -n "$missing_deps" ]; then
        ui_print "❌ Missing required commands:$missing_deps"
        ui_print "Please install missing dependencies and try again."
        exit 1
    fi
    
    install_log "✅ All required dependencies available"
}

# Validate URLs and paths
validate_paths() {
    # Check if MODDIR parent exists
    if [ ! -d "$(dirname "$MODDIR")" ]; then
        ui_print "❌ Module directory parent not found: $(dirname "$MODDIR")"
        exit 1
    fi
    
    # Check if temp directory is writable
    if ! touch "$TMP_ZIP.test" 2>/dev/null; then
        ui_print "❌ Cannot write to temp directory: $(dirname "$TMP_ZIP")"
        exit 1
    fi
    rm -f "$TMP_ZIP.test"
    
    install_log "✅ Path validation passed"
}

# Clean up function
cleanup() {
    install_log "Performing cleanup..."
    rm -f "$TMP_ZIP" 2>/dev/null
    rm -f "$TMP_ZIP.test" 2>/dev/null
    install_log "Cleanup completed"
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Wait for user input with timeout
wait_for_input() {
    local timeout="$1"
    local start_time=$(date +%s)
    
    ui_print "⏱️  Waiting for input (timeout: ${timeout}s)..."
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            install_log "Input timeout reached after ${timeout}s"
            return 2  # Timeout
        fi
        
        # Check for volume key events
        if timeout 1 getevent -lc 1 2>&1 | grep KEY_VOLUME > "$TMPDIR/events" 2>/dev/null; then
            if grep -q KEY_VOLUMEUP "$TMPDIR/events" 2>/dev/null; then
                install_log "Volume UP detected"
                return 1  # Volume UP
            elif grep -q KEY_VOLUMEDOWN "$TMPDIR/events" 2>/dev/null; then
                install_log "Volume DOWN detected"
                return 0  # Volume DOWN
            fi
        fi
        
        sleep 0.5
    done
}

# Download module from GitHub
download_module() {
    ui_print "📥 Downloading module from GitHub..."
    install_log "Download URL: $GITHUB_URL"
    
    # Remove existing file
    rm -f "$TMP_ZIP"
    
    # Download with progress and error handling
    if curl -L --connect-timeout 10 --max-time 300 --retry 3 --retry-delay 2 \
            -o "$TMP_ZIP" "$GITHUB_URL" 2>>"$LOG_FILE"; then
        
        # Verify download
        if [ -f "$TMP_ZIP" ] && [ -s "$TMP_ZIP" ]; then
            local file_size=$(wc -c < "$TMP_ZIP" 2>/dev/null || echo "0")
            ui_print "✅ Download completed (${file_size} bytes)"
            install_log "Download verification passed"
            return 0
        else
            ui_print "❌ Downloaded file is empty or corrupted"
            install_log "Download verification failed"
            return 1
        fi
    else
        ui_print "❌ Download failed"
        install_log "Download failed with curl error"
        return 1
    fi
}

# Verify ZIP file integrity
verify_zip() {
    local zip_file="$1"
    
    if [ ! -f "$zip_file" ]; then
        ui_print "❌ ZIP file not found: $zip_file"
        return 1
    fi
    
    # Test ZIP integrity
    if unzip -t "$zip_file" >/dev/null 2>&1; then
        install_log "✅ ZIP file integrity verified"
        return 0
    else
        ui_print "❌ ZIP file is corrupted"
        install_log "ZIP integrity check failed"
        return 1
    fi
}

# Extract module files
extract_module() {
    local zip_file="$1"
    
    ui_print "📂 Extracting module files..."
    install_log "Extracting to: $MODDIR"
    
    # Create module directory if it doesn't exist
    mkdir -p "$MODDIR" 2>/dev/null
    
    # Extract with error handling
    if unzip -o "$zip_file" -d "$MODDIR" 2>>"$LOG_FILE"; then
        ui_print "✅ Extraction completed"
        install_log "Extraction successful"
        return 0
    else
        ui_print "❌ Extraction failed"
        install_log "Extraction failed"
        return 1
    fi
}

# Set proper permissions
set_permissions() {
    ui_print "⚙️  Setting file permissions..."
    
    # Set directory permissions
    find "$MODDIR" -type d -exec chmod 755 {} \; 2>/dev/null
    
    # Set file permissions
    find "$MODDIR" -type f -exec chmod 644 {} \; 2>/dev/null
    
    # Set executable permissions for scripts
    local scripts=(
        "$MODDIR/service.sh"
        "$MODDIR/customize.sh"
        "$MODDIR/uninstall.sh"
        "$MODDIR/system/xbin/v2ray_monitor.sh"
        "$MODDIR/system/xbin/v2ray_monitor_service"
        "$MODDIR/ui/start_server.sh"
        "$MODDIR/ui/stop_server.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script" 2>/dev/null
            install_log "Set executable: $script"
        fi
    done
    
    # Set executable permissions for CGI scripts
    if [ -d "$MODDIR/ui/www/cgi-bin" ]; then
        find "$MODDIR/ui/www/cgi-bin" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
        install_log "Set executable permissions for CGI scripts"
    fi
    
    ui_print "✅ Permissions set successfully"
}

# Verify installation
verify_installation() {
    ui_print "🔍 Verifying installation..."
    
    local required_files=(
        "$MODDIR/module.prop"
        "$MODDIR/service.sh"
        "$MODDIR/system/xbin/v2ray_monitor.sh"
        "$MODDIR/ui/www/index.html"
        "$MODDIR/ui/www/js/app.js"
    )
    
    local missing_files=0
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            ui_print "❌ Missing required file: $file"
            missing_files=$((missing_files + 1))
        fi
    done
    
    if [ $missing_files -gt 0 ]; then
        ui_print "❌ Installation verification failed: $missing_files missing files"
        return 1
    fi
    
    ui_print "✅ Installation verification passed"
    return 0
}

# Main installation function
main() {
    ui_print "********************************************"
    ui_print "  V2Ray Monitor Module Installer v1.0.4  "
    ui_print "********************************************"
    ui_print ""
    
    # Initialize log
    install_log "Starting V2Ray Monitor Module installation"
    
    # Check dependencies and validate paths
    check_dependencies
    validate_paths
    
    # Show options
    ui_print "📋 Installation Options:"
    ui_print "- [ Vol UP(+): Download latest module from GitHub ]"
    ui_print "- [ Vol DOWN(-): Use existing ZIP file ]"
    ui_print "- [ Wait ${TIMEOUT_SECONDS}s: Auto-select existing ZIP ]"
    ui_print ""
    
    # Wait for user input
    local download_choice
    wait_for_input $TIMEOUT_SECONDS
    download_choice=$?
    
    case $download_choice in
        1)  # Volume UP - Download from GitHub
            ui_print "🔄 Selected: Download latest module from GitHub"
            if download_module; then
                install_log "GitHub download successful"
            else
                ui_print "⚠️  Download failed, checking for existing ZIP file..."
                if [ ! -f "$TMP_ZIP" ]; then
                    ui_print "❌ No existing ZIP file found. Installation aborted."
                    exit 1
                fi
            fi
            ;;
        0)  # Volume DOWN - Use existing ZIP
            ui_print "📁 Selected: Use existing ZIP file"
            if [ ! -f "$TMP_ZIP" ]; then
                ui_print "❌ No existing ZIP file found at: $TMP_ZIP"
                exit 1
            fi
            ;;
        2)  # Timeout - Auto-select existing ZIP
            ui_print "⏰ Timeout reached, using existing ZIP file"
            if [ ! -f "$TMP_ZIP" ]; then
                ui_print "❌ No existing ZIP file found. Installation aborted."
                exit 1
            fi
            ;;
        *)
            ui_print "❌ Invalid selection. Installation aborted."
            exit 1
            ;;
    esac
    
    # Verify ZIP file
    if ! verify_zip "$TMP_ZIP"; then
        ui_print "❌ ZIP file verification failed. Installation aborted."
        exit 1
    fi
    
    # Extract module
    if ! extract_module "$TMP_ZIP"; then
        ui_print "❌ Module extraction failed. Installation aborted."
        exit 1
    fi
    
    # Set permissions
    set_permissions
    
    # Verify installation
    if ! verify_installation; then
        ui_print "❌ Installation verification failed. Please check the logs."
        exit 1
    fi
    
    # Success message
    ui_print ""
    ui_print "✅ Installation completed successfully!"
    ui_print "📋 Installation Summary:"
    ui_print "   - Module installed to: $MODDIR"
    ui_print "   - Log file: $LOG_FILE"
    ui_print "   - Web UI will be available at: http://localhost:9091"
    ui_print ""
    ui_print "🔄 Please reboot your device to activate the module."
    ui_print ""
    
    install_log "Installation completed successfully"
}

# Execute main function
main "$@"
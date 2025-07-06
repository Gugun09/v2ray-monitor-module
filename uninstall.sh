#!/system/bin/sh
# =============================================================================
# V2Ray Monitor Module Uninstaller - Production Ready Version
# =============================================================================

readonly MODULE_DIR="/data/adb/modules/v2ray_monitor"
readonly LOG_FILE="/data/local/tmp/v2ray_monitor_uninstall.log"
readonly PID_FILE="/data/local/tmp/v2ray_monitor.pid"
readonly HTTP_PID_FILE="/tmp/httpd_v2ray_monitor.pid"
readonly CLOUDFLARE_PID_FILE="/tmp/cloudflared.pid"

# Files and directories to clean up
readonly CLEANUP_FILES=(
    "/data/local/tmp/.env"
    "/data/local/tmp/v2ray_monitor.log"
    "/data/local/tmp/v2ray_monitor_status"
    "/data/local/tmp/v2ray_restart_count"
    "/data/local/tmp/service_init.log"
    "/data/local/tmp/v2ray_monitor_install.log"
    "/tmp/cloudflare_log.txt"
    "/tmp/httpd_v2ray_monitor.log"
    "$PID_FILE"
    "$HTTP_PID_FILE"
    "$CLOUDFLARE_PID_FILE"
)

readonly CLEANUP_BINARIES=(
    "/system/xbin/v2ray_monitor.sh"
    "/system/xbin/v2ray_monitor_service"
    "/system/xbin/cloudflared"
)

# Logging function
uninstall_log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [uninstall] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# UI print with logging
ui_print() {
    echo "$1"
    uninstall_log "$1"
}

# Check if process is running by PID
is_process_running() {
    local pid="$1"
    [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1
}

# Stop process safely with timeout
stop_process_safe() {
    local pid="$1"
    local name="$2"
    local timeout="${3:-10}"
    
    if [ -z "$pid" ] || ! is_process_running "$pid"; then
        uninstall_log "$name process not running or PID not found"
        return 0
    fi
    
    uninstall_log "Stopping $name process (PID: $pid)..."
    
    # Try graceful shutdown first
    if kill "$pid" 2>/dev/null; then
        local count=0
        while [ $count -lt $timeout ] && is_process_running "$pid"; do
            sleep 1
            count=$((count + 1))
        done
        
        # Force kill if still running
        if is_process_running "$pid"; then
            uninstall_log "Force killing $name process..."
            kill -9 "$pid" 2>/dev/null
            sleep 2
            
            if is_process_running "$pid"; then
                uninstall_log "⚠️  Failed to stop $name process"
                return 1
            fi
        fi
        
        uninstall_log "✅ $name process stopped successfully"
        return 0
    else
        uninstall_log "❌ Failed to send signal to $name process"
        return 1
    fi
}

# Stop all running services
stop_all_services() {
    ui_print "🛑 Stopping all V2Ray Monitor services..."
    
    local stopped_count=0
    local failed_count=0
    
    # Stop V2Ray Monitor main process
    if [ -f "$PID_FILE" ]; then
        local monitor_pid=$(cat "$PID_FILE" 2>/dev/null)
        if stop_process_safe "$monitor_pid" "V2Ray Monitor"; then
            stopped_count=$((stopped_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    else
        # Try to find by process name
        local monitor_pid=$(pgrep -f "v2ray_monitor.sh")
        if [ -n "$monitor_pid" ]; then
            if stop_process_safe "$monitor_pid" "V2Ray Monitor"; then
                stopped_count=$((stopped_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        fi
    fi
    
    # Stop HTTP server
    if [ -f "$HTTP_PID_FILE" ]; then
        local http_pid=$(cat "$HTTP_PID_FILE" 2>/dev/null)
        if stop_process_safe "$http_pid" "HTTP Server"; then
            stopped_count=$((stopped_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    else
        # Try to find by process name
        local http_pid=$(pgrep -f "busybox httpd.*9091")
        if [ -n "$http_pid" ]; then
            if stop_process_safe "$http_pid" "HTTP Server"; then
                stopped_count=$((stopped_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        fi
    fi
    
    # Stop Cloudflare Tunnel
    if [ -f "$CLOUDFLARE_PID_FILE" ]; then
        local cf_pid=$(cat "$CLOUDFLARE_PID_FILE" 2>/dev/null)
        if stop_process_safe "$cf_pid" "Cloudflare Tunnel"; then
            stopped_count=$((stopped_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    else
        # Try to find by process name
        local cf_pid=$(pgrep -f "cloudflared")
        if [ -n "$cf_pid" ]; then
            if stop_process_safe "$cf_pid" "Cloudflare Tunnel"; then
                stopped_count=$((stopped_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        fi
    fi
    
    # Summary
    if [ $stopped_count -gt 0 ]; then
        ui_print "✅ Stopped $stopped_count service(s) successfully"
    fi
    
    if [ $failed_count -gt 0 ]; then
        ui_print "⚠️  Failed to stop $failed_count service(s)"
        ui_print "ℹ️  Some processes may require manual intervention"
    fi
    
    if [ $stopped_count -eq 0 ] && [ $failed_count -eq 0 ]; then
        ui_print "ℹ️  No running services found"
    fi
}

# Remove files safely
remove_files() {
    ui_print "🗑️  Removing configuration files and logs..."
    
    local removed_count=0
    local failed_count=0
    
    for file in "${CLEANUP_FILES[@]}"; do
        if [ -f "$file" ]; then
            uninstall_log "Removing file: $file"
            if rm -f "$file" 2>/dev/null; then
                removed_count=$((removed_count + 1))
                uninstall_log "✅ Removed: $file"
            else
                failed_count=$((failed_count + 1))
                uninstall_log "❌ Failed to remove: $file"
            fi
        else
            uninstall_log "File not found (skipping): $file"
        fi
    done
    
    ui_print "📁 Removed $removed_count file(s), $failed_count failed"
}

# Remove binaries safely
remove_binaries() {
    ui_print "🗑️  Removing system binaries..."
    
    local removed_count=0
    local failed_count=0
    
    for binary in "${CLEANUP_BINARIES[@]}"; do
        if [ -f "$binary" ]; then
            uninstall_log "Removing binary: $binary"
            if rm -f "$binary" 2>/dev/null; then
                removed_count=$((removed_count + 1))
                uninstall_log "✅ Removed: $binary"
            else
                failed_count=$((failed_count + 1))
                uninstall_log "❌ Failed to remove: $binary"
            fi
        else
            uninstall_log "Binary not found (skipping): $binary"
        fi
    done
    
    ui_print "🔧 Removed $removed_count binary(ies), $failed_count failed"
}

# Remove module directory
remove_module_directory() {
    ui_print "🗑️  Removing module directory..."
    
    if [ ! -d "$MODULE_DIR" ]; then
        ui_print "ℹ️  Module directory not found: $MODULE_DIR"
        return 0
    fi
    
    # Get directory size for logging
    local dir_size=$(du -sh "$MODULE_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    uninstall_log "Module directory size: $dir_size"
    
    # Remove directory recursively
    if rm -rf "$MODULE_DIR" 2>/dev/null; then
        ui_print "✅ Module directory removed successfully"
        uninstall_log "✅ Removed module directory: $MODULE_DIR"
        return 0
    else
        ui_print "❌ Failed to remove module directory"
        uninstall_log "❌ Failed to remove: $MODULE_DIR"
        return 1
    fi
}

# Check for remaining files
check_remaining_files() {
    ui_print "🔍 Checking for remaining files..."
    
    local remaining_files=""
    local remaining_count=0
    
    # Check cleanup files
    for file in "${CLEANUP_FILES[@]}"; do
        if [ -f "$file" ]; then
            remaining_files="$remaining_files\n  - $file"
            remaining_count=$((remaining_count + 1))
        fi
    done
    
    # Check binaries
    for binary in "${CLEANUP_BINARIES[@]}"; do
        if [ -f "$binary" ]; then
            remaining_files="$remaining_files\n  - $binary"
            remaining_count=$((remaining_count + 1))
        fi
    done
    
    # Check module directory
    if [ -d "$MODULE_DIR" ]; then
        remaining_files="$remaining_files\n  - $MODULE_DIR (directory)"
        remaining_count=$((remaining_count + 1))
    fi
    
    if [ $remaining_count -gt 0 ]; then
        ui_print "⚠️  Found $remaining_count remaining file(s):"
        echo -e "$remaining_files"
        ui_print "ℹ️  Manual cleanup may be required"
        return 1
    else
        ui_print "✅ No remaining files found"
        return 0
    fi
}

# Check if running processes exist
check_running_processes() {
    ui_print "🔍 Checking for running processes..."
    
    local running_processes=""
    local process_count=0
    
    # Check for V2Ray Monitor processes
    local monitor_pids=$(pgrep -f "v2ray_monitor")
    if [ -n "$monitor_pids" ]; then
        running_processes="$running_processes\n  - V2Ray Monitor: $monitor_pids"
        process_count=$((process_count + 1))
    fi
    
    # Check for HTTP server
    local http_pids=$(pgrep -f "busybox httpd.*9091")
    if [ -n "$http_pids" ]; then
        running_processes="$running_processes\n  - HTTP Server: $http_pids"
        process_count=$((process_count + 1))
    fi
    
    # Check for Cloudflare Tunnel
    local cf_pids=$(pgrep -f "cloudflared")
    if [ -n "$cf_pids" ]; then
        running_processes="$running_processes\n  - Cloudflare Tunnel: $cf_pids"
        process_count=$((process_count + 1))
    fi
    
    if [ $process_count -gt 0 ]; then
        ui_print "⚠️  Found $process_count running process(es):"
        echo -e "$running_processes"
        ui_print "ℹ️  These processes may restart after reboot"
        return 1
    else
        ui_print "✅ No related processes running"
        return 0
    fi
}

# Backup important data before uninstall
backup_user_data() {
    ui_print "💾 Creating backup of user configuration..."
    
    local backup_dir="/data/local/tmp/v2ray_monitor_backup_$(date +%s)"
    local backup_created=false
    
    # Create backup directory
    if mkdir -p "$backup_dir" 2>/dev/null; then
        uninstall_log "Created backup directory: $backup_dir"
        
        # Backup environment file
        if [ -f "/data/local/tmp/.env" ]; then
            if cp "/data/local/tmp/.env" "$backup_dir/.env" 2>/dev/null; then
                uninstall_log "Backed up environment configuration"
                backup_created=true
            fi
        fi
        
        # Backup logs if they exist
        if [ -f "/data/local/tmp/v2ray_monitor.log" ]; then
            if cp "/data/local/tmp/v2ray_monitor.log" "$backup_dir/monitor.log" 2>/dev/null; then
                uninstall_log "Backed up monitor logs"
                backup_created=true
            fi
        fi
        
        if $backup_created; then
            ui_print "✅ User data backed up to: $backup_dir"
            ui_print "ℹ️  You can restore this data if you reinstall the module"
        else
            rmdir "$backup_dir" 2>/dev/null
            ui_print "ℹ️  No user data found to backup"
        fi
    else
        ui_print "⚠️  Failed to create backup directory"
    fi
}

# Display uninstall summary
show_uninstall_summary() {
    ui_print ""
    ui_print "📋 Uninstall Summary:"
    ui_print "========================"
    
    # Check final status
    local services_stopped=true
    local files_removed=true
    local processes_clean=true
    
    if check_running_processes >/dev/null 2>&1; then
        processes_clean=false
    fi
    
    if check_remaining_files >/dev/null 2>&1; then
        files_removed=false
    fi
    
    # Display results
    if $services_stopped && $files_removed && $processes_clean; then
        ui_print "✅ Uninstall completed successfully!"
        ui_print "✅ All services stopped"
        ui_print "✅ All files removed"
        ui_print "✅ No remaining processes"
    else
        ui_print "⚠️  Uninstall completed with warnings:"
        if ! $services_stopped; then
            ui_print "   - Some services may still be running"
        fi
        if ! $files_removed; then
            ui_print "   - Some files may remain on system"
        fi
        if ! $processes_clean; then
            ui_print "   - Some processes may still be active"
        fi
    fi
    
    ui_print ""
    ui_print "🔄 Next Steps:"
    ui_print "   1. Reboot your device to complete removal"
    ui_print "   2. Check that no V2Ray Monitor processes restart"
    ui_print "   3. Verify module is removed from Magisk Manager"
    ui_print ""
    ui_print "📝 Log file: $LOG_FILE"
    ui_print ""
}

# Cleanup function for script termination
cleanup_uninstaller() {
    uninstall_log "Uninstaller cleanup initiated"
    # Any cleanup needed for the uninstaller itself
}

# Set up signal handlers
trap cleanup_uninstaller EXIT INT TERM

# Main uninstall function
main() {
    ui_print "********************************************"
    ui_print "  V2Ray Monitor Module Uninstaller v1.0.3  "
    ui_print "********************************************"
    ui_print ""
    
    # Initialize log
    uninstall_log "Starting V2Ray Monitor Module uninstallation"
    
    # Confirmation prompt
    ui_print "⚠️  This will completely remove V2Ray Monitor Module"
    ui_print "📋 What will be removed:"
    ui_print "   - All module files and directories"
    ui_print "   - Configuration files and logs"
    ui_print "   - System binaries and services"
    ui_print "   - Running processes"
    ui_print ""
    
    # Wait for confirmation (simplified for script)
    ui_print "🔄 Proceeding with uninstallation..."
    ui_print ""
    
    # Create backup of user data
    backup_user_data
    
    # Stop all services
    stop_all_services
    
    # Remove files and binaries
    remove_files
    remove_binaries
    
    # Remove module directory
    remove_module_directory
    
    # Final checks
    ui_print ""
    ui_print "🔍 Performing final verification..."
    check_remaining_files
    check_running_processes
    
    # Show summary
    show_uninstall_summary
    
    uninstall_log "Uninstallation process completed"
}

# Execute main function
main "$@"
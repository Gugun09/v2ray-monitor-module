// =============================================================================
// V2Ray Monitor Dashboard - Production Ready Application
// =============================================================================

class V2RayMonitor {
    constructor() {
        this.config = {
            refreshInterval: 5000,
            logRefreshInterval: 3000,
            maxToasts: 5,
            retryAttempts: 3,
            retryDelay: 1000,
            apiTimeout: 10000,
            apiEndpoints: {
                status: '/cgi-bin/status.sh',
                log: '/cgi-bin/log.sh',
                start: '/cgi-bin/start.sh',
                stop: '/cgi-bin/stop.sh',
                restart: '/cgi-bin/restart.sh',
                usbStatus: '/cgi-bin/status_usb.sh',
                usbTether: '/cgi-bin/usb_tether.sh',
                tunnel: '/cgi-bin/tunnel.sh',
                telegramConfig: '/cgi-bin/get_bot_config.sh',
                updateTelegramConfig: '/cgi-bin/update_env.sh',
                sendTestMessage: '/cgi-bin/send_telegram_message.sh',
                version: '/cgi-bin/get_version.sh',
                checkUpdate: '/cgi-bin/check_update.sh'
            }
        };
        
        this.state = {
            isDarkMode: localStorage.getItem('darkMode') === 'true',
            isAutoScrollEnabled: true,
            lastLogLength: 0,
            startTime: Date.now(),
            isOnline: navigator.onLine,
            retryCount: 0,
            lastUpdateTime: Date.now()
        };
        
        this.intervals = {};
        this.init();
    }

    // =============================================================================
    // Initialization
    // =============================================================================

    init() {
        this.setupEventListeners();
        this.applyDarkMode();
        this.loadInitialData();
        this.startPeriodicUpdates();
        this.showToast('Dashboard initialized successfully', 'success');
    }

    setupEventListeners() {
        // Auto-scroll toggle
        const autoScrollToggle = document.getElementById('autoScroll');
        if (autoScrollToggle) {
            autoScrollToggle.addEventListener('change', (e) => {
                this.state.isAutoScrollEnabled = e.target.checked;
                this.showToast(`Auto-scroll ${e.target.checked ? 'enabled' : 'disabled'}`, 'info');
            });
        }

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey || e.metaKey) {
                switch (e.key) {
                    case 'r':
                        e.preventDefault();
                        this.refreshAll();
                        break;
                    case 'd':
                        e.preventDefault();
                        this.toggleDarkMode();
                        break;
                }
            }
        });

        // Window visibility change
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.pauseUpdates();
            } else {
                this.resumeUpdates();
            }
        });

        // Online/offline detection
        window.addEventListener('online', () => {
            this.state.isOnline = true;
            this.showToast('Connection restored', 'success');
            this.resumeUpdates();
        });

        window.addEventListener('offline', () => {
            this.state.isOnline = false;
            this.showToast('Connection lost', 'warning');
            this.pauseUpdates();
        });

        // Unload handler
        window.addEventListener('beforeunload', () => {
            this.pauseUpdates();
        });
    }

    loadInitialData() {
        this.checkStatus();
        this.checkUsbStatus();
        this.updateLog();
        this.loadTelegramConfig();
        this.loadVersionInfo();
        this.checkForUpdates();
        this.updateUptime();
    }

    startPeriodicUpdates() {
        this.intervals.status = setInterval(() => this.checkStatus(), this.config.refreshInterval);
        this.intervals.usbStatus = setInterval(() => this.checkUsbStatus(), this.config.refreshInterval);
        this.intervals.log = setInterval(() => this.updateLog(), this.config.logRefreshInterval);
        this.intervals.uptime = setInterval(() => this.updateUptime(), 1000);
        this.intervals.tunnelUrl = setInterval(() => this.updateTunnelUrl(), 10000);
    }

    pauseUpdates() {
        Object.values(this.intervals).forEach(interval => clearInterval(interval));
        this.intervals = {};
    }

    resumeUpdates() {
        if (Object.keys(this.intervals).length === 0) {
            this.startPeriodicUpdates();
            this.refreshAll();
        }
    }

    // =============================================================================
    // UI Utilities
    // =============================================================================

    showToast(message, type = 'info', duration = 5000) {
        const toastContainer = document.getElementById('toastContainer');
        if (!toastContainer) return;

        const toastId = `toast-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        
        const icons = {
            success: 'fa-check-circle',
            error: 'fa-times-circle',
            warning: 'fa-exclamation-triangle',
            info: 'fa-info-circle'
        };
        
        const colors = {
            success: 'from-green-500 to-green-600',
            error: 'from-red-500 to-red-600',
            warning: 'from-yellow-500 to-yellow-600',
            info: 'from-blue-500 to-blue-600'
        };

        const toastHtml = `
            <div id="${toastId}" class="toast flex items-center bg-gradient-to-r ${colors[type]} text-white px-6 py-4 rounded-lg shadow-lg mb-2">
                <i class="fas ${icons[type]} mr-3 text-xl"></i>
                <div class="flex-1 font-medium">${message}</div>
                <button type="button" class="ml-4 text-white opacity-70 hover:opacity-100 transition-opacity" onclick="this.parentElement.remove()">
                    <i class="fas fa-times"></i>
                </button>
            </div>
        `;

        toastContainer.insertAdjacentHTML('beforeend', toastHtml);

        // Auto-remove after duration
        setTimeout(() => {
            const toast = document.getElementById(toastId);
            if (toast) {
                toast.style.animation = 'slideOut 0.3s ease-in forwards';
                setTimeout(() => toast.remove(), 300);
            }
        }, duration);

        // Limit number of toasts
        const toasts = toastContainer.children;
        if (toasts.length > this.config.maxToasts) {
            toasts[0].remove();
        }
    }

    showLoading(show = true) {
        const overlay = document.getElementById('loadingOverlay');
        if (overlay) {
            overlay.classList.toggle('hidden', !show);
        }
    }

    updateElement(id, content, className = null) {
        const element = document.getElementById(id);
        if (element) {
            if (typeof content === 'string') {
                element.textContent = content;
            } else {
                element.innerHTML = content;
            }
            if (className) {
                element.className = className;
            }
        }
    }

    // =============================================================================
    // API Calls with Retry Logic
    // =============================================================================

    async apiCall(endpoint, options = {}) {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), this.config.apiTimeout);

        try {
            const response = await fetch(endpoint, {
                signal: controller.signal,
                ...options
            });
            
            clearTimeout(timeoutId);
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            return await response.text();
        } catch (error) {
            clearTimeout(timeoutId);
            
            if (error.name === 'AbortError') {
                throw new Error('Request timeout');
            }
            
            console.error(`API call failed for ${endpoint}:`, error);
            throw error;
        }
    }

    async apiCallWithRetry(endpoint, options = {}) {
        let lastError;
        
        for (let attempt = 1; attempt <= this.config.retryAttempts; attempt++) {
            try {
                return await this.apiCall(endpoint, options);
            } catch (error) {
                lastError = error;
                
                if (attempt < this.config.retryAttempts) {
                    await new Promise(resolve => setTimeout(resolve, this.config.retryDelay * attempt));
                }
            }
        }
        
        throw lastError;
    }

    async apiCallWithToast(endpoint, options = {}, successMessage = null, errorMessage = null) {
        try {
            this.showLoading(true);
            const result = await this.apiCallWithRetry(endpoint, options);
            this.showLoading(false);
            
            if (successMessage) {
                this.showToast(successMessage, 'success');
            }
            
            return result;
        } catch (error) {
            this.showLoading(false);
            const message = errorMessage || `Operation failed: ${error.message}`;
            this.showToast(message, 'error');
            throw error;
        }
    }

    // =============================================================================
    // Status Management
    // =============================================================================

    async checkStatus() {
        try {
            const status = await this.apiCall(this.config.apiEndpoints.status);
            const isRunning = status.includes('running') || status.includes('Running') || status.includes('✅');
            
            this.updateStatusDisplay('status', isRunning ? 'Online' : 'Offline', isRunning);
            this.updateConnectionIndicator('connectionIndicator', isRunning);
            this.updateElement('vpnStatus', isRunning ? 'Connected' : 'Disconnected');
            
            this.state.lastUpdateTime = Date.now();
            
        } catch (error) {
            this.updateStatusDisplay('status', 'Error', false);
            this.updateElement('vpnStatus', 'Unknown');
            console.error('Status check failed:', error);
        }
    }

    async checkUsbStatus() {
        try {
            const status = await this.apiCall(this.config.apiEndpoints.usbStatus);
            const isEnabled = status.trim() === 'enabled';
            
            this.updateStatusDisplay('usbStatus', isEnabled ? 'Enabled' : 'Disabled', isEnabled);
            this.updateConnectionIndicator('usbIndicator', isEnabled);
            this.updateElement('usbStatusText', isEnabled ? 'Active' : 'Inactive');
            
        } catch (error) {
            this.updateStatusDisplay('usbStatus', 'Error', false);
            this.updateElement('usbStatusText', 'Unknown');
            console.error('USB status check failed:', error);
        }
    }

    updateStatusDisplay(elementId, text, isOnline) {
        const element = document.getElementById(elementId);
        if (element) {
            element.innerHTML = `
                <span class="connection-indicator ${isOnline ? 'connection-online' : 'connection-offline'}"></span>
                ${text}
            `;
            element.className = `status-badge ${isOnline ? 'status-online' : 'status-offline'}`;
        }
    }

    updateConnectionIndicator(elementId, isOnline) {
        const indicator = document.getElementById(elementId);
        if (indicator) {
            indicator.className = `connection-indicator ${isOnline ? 'connection-online' : 'connection-offline'}`;
        }
    }

    // =============================================================================
    // Control Functions
    // =============================================================================

    async controlV2Ray(action) {
        const endpoints = {
            start: this.config.apiEndpoints.start,
            stop: this.config.apiEndpoints.stop,
            restart: this.config.apiEndpoints.restart
        };

        const messages = {
            start: 'V2Ray started successfully',
            stop: 'V2Ray stopped successfully',
            restart: 'V2Ray restarted successfully'
        };

        if (!endpoints[action]) {
            this.showToast(`Invalid action: ${action}`, 'error');
            return;
        }

        try {
            await this.apiCallWithToast(
                endpoints[action],
                {},
                messages[action],
                `Failed to ${action} V2Ray`
            );
            
            // Refresh status after action
            setTimeout(() => this.checkStatus(), 2000);
        } catch (error) {
            // Error already handled by apiCallWithToast
        }
    }

    async controlTethering(action) {
        if (!['start', 'stop'].includes(action)) {
            this.showToast(`Invalid tethering action: ${action}`, 'error');
            return;
        }

        try {
            await this.apiCallWithToast(
                `${this.config.apiEndpoints.usbTether}?action=${action}`,
                {},
                `USB Tethering ${action === 'start' ? 'enabled' : 'disabled'} successfully`,
                `Failed to ${action} USB Tethering`
            );
            
            // Refresh status after action
            setTimeout(() => this.checkUsbStatus(), 2000);
        } catch (error) {
            // Error already handled by apiCallWithToast
        }
    }

    async controlTunnel(action) {
        if (!['start', 'stop'].includes(action)) {
            this.showToast(`Invalid tunnel action: ${action}`, 'error');
            return;
        }

        try {
            await this.apiCallWithToast(
                `${this.config.apiEndpoints.tunnel}?${action}`,
                {},
                `Cloudflare Tunnel ${action === 'start' ? 'started' : 'stopped'} successfully`,
                `Failed to ${action} Cloudflare Tunnel`
            );
            
            if (action === 'start') {
                setTimeout(() => this.updateTunnelUrl(), 5000);
            } else {
                // Clear tunnel URL when stopped
                const tunnelInput = document.getElementById('tunnelUrl');
                if (tunnelInput) {
                    tunnelInput.value = '🔄 Waiting for URL...';
                }
            }
        } catch (error) {
            // Error already handled by apiCallWithToast
        }
    }

    // =============================================================================
    // Log Management
    // =============================================================================

    async updateLog() {
        try {
            const logs = await this.apiCall(this.config.apiEndpoints.log);
            const logElement = document.getElementById('log');
            
            if (logElement && logs !== logElement.textContent) {
                logElement.textContent = logs;
                
                if (this.state.isAutoScrollEnabled) {
                    this.scrollToBottom();
                }
            }
        } catch (error) {
            this.updateElement('log', '🚫 Failed to load logs\n❌ ' + error.message);
            console.error('Log update failed:', error);
        }
    }

    scrollToBottom() {
        const logElement = document.getElementById('log');
        if (logElement) {
            logElement.scrollTop = logElement.scrollHeight;
        }
    }

    clearLog() {
        if (confirm('Are you sure you want to clear the log display?\n\nNote: This only clears the display, not the actual log file.')) {
            this.updateElement('log', '📝 Log display cleared\nℹ️  Refresh to reload logs from file');
            this.showToast('Log display cleared', 'info');
        }
    }

    downloadLog() {
        const logContent = document.getElementById('log')?.textContent || '';
        
        if (!logContent.trim()) {
            this.showToast('No log content to download', 'warning');
            return;
        }

        try {
            const blob = new Blob([logContent], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            
            const a = document.createElement('a');
            a.href = url;
            a.download = `v2ray-monitor-log-${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}.txt`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            
            this.showToast('Log downloaded successfully', 'success');
        } catch (error) {
            this.showToast('Failed to download log', 'error');
            console.error('Download failed:', error);
        }
    }

    // =============================================================================
    // Telegram Configuration
    // =============================================================================

    async loadTelegramConfig() {
        try {
            const response = await this.apiCall(this.config.apiEndpoints.telegramConfig);
            const data = JSON.parse(response);
            
            const botTokenInput = document.getElementById('botToken');
            const chatIdInput = document.getElementById('chatId');
            
            if (botTokenInput && data.botToken) {
                botTokenInput.value = data.botToken;
            }
            
            if (chatIdInput && data.chatId) {
                chatIdInput.value = data.chatId;
            }
            
            this.updateElement('deviceInfo', data.hostname || 'Unknown Device');
            
            const tunnelInput = document.getElementById('tunnelUrl');
            if (tunnelInput && data.tunnelUrl) {
                tunnelInput.value = data.tunnelUrl;
            }
        } catch (error) {
            this.showToast('Failed to load Telegram configuration', 'error');
            console.error('Telegram config load failed:', error);
        }
    }

    async saveTelegramConfig() {
        const botTokenInput = document.getElementById('botToken');
        const chatIdInput = document.getElementById('chatId');
        
        if (!botTokenInput || !chatIdInput) {
            this.showToast('Configuration form not found', 'error');
            return;
        }

        const botToken = botTokenInput.value.trim();
        const chatId = chatIdInput.value.trim();
        
        if (!botToken || !chatId) {
            this.showToast('Please fill in both Bot Token and Chat ID', 'warning');
            return;
        }

        // Basic validation
        if (!botToken.match(/^\d+:[A-Za-z0-9_-]+$/)) {
            this.showToast('Invalid bot token format. Expected: 123456789:ABCdefGHI...', 'error');
            return;
        }

        if (!chatId.match(/^-?\d+$/)) {
            this.showToast('Invalid chat ID format. Expected numeric value.', 'error');
            return;
        }

        try {
            const response = await this.apiCallWithToast(
                this.config.apiEndpoints.updateTelegramConfig,
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ botToken, chatId })
                },
                'Telegram configuration saved successfully',
                'Failed to save Telegram configuration'
            );

            // Parse response to check for errors
            try {
                const result = JSON.parse(response);
                if (result.error) {
                    this.showToast(result.error, 'error');
                }
            } catch (e) {
                // Response might not be JSON, which is okay
            }
        } catch (error) {
            // Error already handled by apiCallWithToast
        }
    }

    async testTelegramConfig() {
        try {
            const response = await this.apiCallWithToast(
                this.config.apiEndpoints.sendTestMessage,
                {},
                null,
                'Failed to send test message'
            );
            
            try {
                const result = JSON.parse(response);
                if (result.ok) {
                    this.showToast('Test message sent successfully! Check your Telegram.', 'success');
                } else {
                    this.showToast(result.error || 'Failed to send test message', 'error');
                }
            } catch (e) {
                // If response is not JSON, assume success if no error was thrown
                this.showToast('Test message sent successfully!', 'success');
            }
        } catch (error) {
            // Error already handled by apiCallWithToast
        }
    }

    // =============================================================================
    // Utility Functions
    // =============================================================================

    async updateTunnelUrl() {
        try {
            const response = await this.apiCall(this.config.apiEndpoints.telegramConfig);
            const data = JSON.parse(response);
            
            const tunnelInput = document.getElementById('tunnelUrl');
            if (tunnelInput && data.tunnelUrl && data.tunnelUrl !== tunnelInput.value) {
                tunnelInput.value = data.tunnelUrl;
            }
        } catch (error) {
            // Silently fail for tunnel URL updates
            console.debug('Tunnel URL update failed:', error);
        }
    }

    copyTunnelUrl() {
        const tunnelInput = document.getElementById('tunnelUrl');
        if (!tunnelInput) {
            this.showToast('Tunnel URL input not found', 'error');
            return;
        }

        const url = tunnelInput.value;
        if (!url || url === '🔄 Waiting for URL...') {
            this.showToast('No tunnel URL available to copy', 'warning');
            return;
        }

        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(url).then(() => {
                this.showToast('Tunnel URL copied to clipboard!', 'success');
            }).catch(() => {
                this.fallbackCopyToClipboard(url);
            });
        } else {
            this.fallbackCopyToClipboard(url);
        }
    }

    fallbackCopyToClipboard(text) {
        const textArea = document.createElement('textarea');
        textArea.value = text;
        textArea.style.position = 'fixed';
        textArea.style.left = '-999999px';
        textArea.style.top = '-999999px';
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();
        
        try {
            document.execCommand('copy');
            this.showToast('Tunnel URL copied to clipboard!', 'success');
        } catch (err) {
            this.showToast('Failed to copy URL', 'error');
        }
        
        document.body.removeChild(textArea);
    }

    togglePasswordVisibility(inputId) {
        const input = document.getElementById(inputId);
        const eyeIcon = document.getElementById(inputId + 'Eye');
        
        if (input && eyeIcon) {
            if (input.type === 'password') {
                input.type = 'text';
                eyeIcon.className = 'fas fa-eye-slash';
            } else {
                input.type = 'password';
                eyeIcon.className = 'fas fa-eye';
            }
        }
    }

    toggleDarkMode() {
        this.state.isDarkMode = !this.state.isDarkMode;
        localStorage.setItem('darkMode', this.state.isDarkMode);
        this.applyDarkMode();
        this.showToast(`Dark mode ${this.state.isDarkMode ? 'enabled' : 'disabled'}`, 'info');
    }

    applyDarkMode() {
        document.body.classList.toggle('dark-mode', this.state.isDarkMode);
        const moonIcon = document.querySelector('button[onclick="toggleDarkMode()"] i');
        if (moonIcon) {
            moonIcon.className = this.state.isDarkMode ? 'fas fa-sun text-lg' : 'fas fa-moon text-lg';
        }
    }

    updateUptime() {
        const uptimeElement = document.getElementById('uptime');
        if (uptimeElement) {
            const uptime = Date.now() - this.state.startTime;
            const hours = Math.floor(uptime / (1000 * 60 * 60));
            const minutes = Math.floor((uptime % (1000 * 60 * 60)) / (1000 * 60));
            const seconds = Math.floor((uptime % (1000 * 60)) / 1000);
            
            uptimeElement.textContent = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        }
    }

    async loadVersionInfo() {
        try {
            const response = await this.apiCall(this.config.apiEndpoints.version);
            const data = JSON.parse(response);
            
            this.updateElement('devName', data.devName || 'Unknown');
            this.updateElement('appVersion', data.appVersion || 'Unknown');
            this.updateElement('codeVersion', data.codeVersion || 'Unknown');
        } catch (error) {
            console.error('Version info load failed:', error);
            // Don't show toast for version info failures
        }
    }

    async checkForUpdates() {
        try {
            const response = await this.apiCall(this.config.apiEndpoints.checkUpdate);
            const data = JSON.parse(response);
            const currentVersion = document.getElementById('appVersion')?.textContent;
            
            if (data.version && data.version !== currentVersion && data.zipUrl) {
                this.showToast(
                    `Update available: v${data.version} <button onclick="app.doUpdate('${data.zipUrl}')" class="underline ml-2 hover:text-blue-200">Update Now</button>`,
                    'info',
                    15000
                );
            }
        } catch (error) {
            console.debug('Update check failed:', error);
            // Silently fail for update checks
        }
    }

    async doUpdate(url) {
        if (!url) {
            this.showToast('Invalid update URL', 'error');
            return;
        }

        if (confirm('Are you sure you want to update? This will require a reboot.')) {
            try {
                await this.apiCallWithToast(
                    `/cgi-bin/do_update.sh?url=${encodeURIComponent(url)}`,
                    {},
                    'Update completed successfully! Please reboot your device.',
                    'Update failed'
                );
            } catch (error) {
                // Error already handled by apiCallWithToast
            }
        }
    }

    refreshAll() {
        const refreshIcon = document.getElementById('refreshIcon');
        if (refreshIcon) {
            refreshIcon.style.animation = 'spin 1s linear infinite';
            setTimeout(() => {
                refreshIcon.style.animation = '';
            }, 1000);
        }

        // Reset retry count on manual refresh
        this.state.retryCount = 0;

        this.checkStatus();
        this.checkUsbStatus();
        this.updateLog();
        this.loadTelegramConfig();
        this.updateTunnelUrl();
        
        this.showToast('Dashboard refreshed', 'info');
    }
}

// =============================================================================
// Global Functions (for onclick handlers)
// =============================================================================

let app;

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    try {
        app = new V2RayMonitor();
    } catch (error) {
        console.error('Failed to initialize V2Ray Monitor:', error);
        
        // Show fallback error message
        const errorDiv = document.createElement('div');
        errorDiv.innerHTML = `
            <div class="fixed inset-0 bg-red-600 text-white flex items-center justify-center z-50">
                <div class="text-center p-8">
                    <h1 class="text-2xl font-bold mb-4">Initialization Failed</h1>
                    <p class="mb-4">Failed to start V2Ray Monitor Dashboard</p>
                    <button onclick="location.reload()" class="bg-white text-red-600 px-4 py-2 rounded">
                        Reload Page
                    </button>
                </div>
            </div>
        `;
        document.body.appendChild(errorDiv);
    }
});

// Global functions for HTML onclick handlers
function controlV2Ray(action) {
    app?.controlV2Ray(action);
}

function controlTethering(action) {
    app?.controlTethering(action);
}

function controlTunnel(action) {
    app?.controlTunnel(action);
}

function copyTunnelUrl() {
    app?.copyTunnelUrl();
}

function togglePasswordVisibility(inputId) {
    app?.togglePasswordVisibility(inputId);
}

function saveTelegramConfig() {
    app?.saveTelegramConfig();
}

function testTelegramConfig() {
    app?.testTelegramConfig();
}

function toggleDarkMode() {
    app?.toggleDarkMode();
}

function refreshAll() {
    app?.refreshAll();
}

function scrollToBottom() {
    app?.scrollToBottom();
}

function clearLog() {
    app?.clearLog();
}

function downloadLog() {
    app?.downloadLog();
}

// Add CSS animation for slideOut
const style = document.createElement('style');
style.textContent = `
    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);
// =============================================================================
// V2Ray Monitor Dashboard - Main Application Script
// =============================================================================

class V2RayMonitor {
    constructor() {
        this.config = {
            refreshInterval: 5000,
            logRefreshInterval: 3000,
            maxToasts: 5,
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
            startTime: Date.now()
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
    }

    resumeUpdates() {
        this.startPeriodicUpdates();
        this.refreshAll();
    }

    // =============================================================================
    // UI Utilities
    // =============================================================================

    showToast(message, type = 'info', duration = 5000) {
        const toastContainer = document.getElementById('toastContainer');
        const toastId = `toast-${Date.now()}`;
        
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
            <div id="${toastId}" class="toast flex items-center bg-gradient-to-r ${colors[type]} text-white px-6 py-4 rounded-lg shadow-lg">
                <i class="fas ${icons[type]} mr-3 text-xl"></i>
                <div class="flex-1 font-medium">${message}</div>
                <button type="button" class="ml-4 text-white opacity-70 hover:opacity-100 transition-opacity" onclick="this.parentElement.remove()">
                    <i class="fas fa-times"></i>
                </button>
            </div>
        `;

        const toastElement = document.createElement('div');
        toastElement.innerHTML = toastHtml;
        toastContainer.appendChild(toastElement);

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
    // API Calls
    // =============================================================================

    async apiCall(endpoint, options = {}) {
        try {
            const response = await fetch(endpoint, {
                timeout: 10000,
                ...options
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            return await response.text();
        } catch (error) {
            console.error(`API call failed for ${endpoint}:`, error);
            throw error;
        }
    }

    async apiCallWithToast(endpoint, options = {}, successMessage = null, errorMessage = null) {
        try {
            this.showLoading(true);
            const result = await this.apiCall(endpoint, options);
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
            const isRunning = status.includes('running') || status.includes('Running');
            
            this.updateStatusDisplay('status', isRunning ? 'Online' : 'Offline', isRunning);
            this.updateConnectionIndicator('connectionIndicator', isRunning);
            this.updateElement('vpnStatus', isRunning ? 'Connected' : 'Disconnected');
            
        } catch (error) {
            this.updateStatusDisplay('status', 'Error', false);
            this.updateElement('vpnStatus', 'Unknown');
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
        try {
            await this.apiCallWithToast(
                `${this.config.apiEndpoints.tunnel}?${action}`,
                {},
                `Cloudflare Tunnel ${action === 'start' ? 'started' : 'stopped'} successfully`,
                `Failed to ${action} Cloudflare Tunnel`
            );
            
            if (action === 'start') {
                setTimeout(() => this.updateTunnelUrl(), 5000);
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
            this.updateElement('log', '🚫 Failed to load logs');
        }
    }

    scrollToBottom() {
        const logElement = document.getElementById('log');
        if (logElement) {
            logElement.scrollTop = logElement.scrollHeight;
        }
    }

    clearLog() {
        if (confirm('Are you sure you want to clear the log?')) {
            this.updateElement('log', '📝 Log cleared');
            this.showToast('Log cleared successfully', 'info');
        }
    }

    downloadLog() {
        const logContent = document.getElementById('log').textContent;
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
    }

    // =============================================================================
    // Telegram Configuration
    // =============================================================================

    async loadTelegramConfig() {
        try {
            const response = await this.apiCall(this.config.apiEndpoints.telegramConfig);
            const data = JSON.parse(response);
            
            this.updateElement('botToken', data.botToken);
            this.updateElement('chatId', data.chatId);
            this.updateElement('deviceInfo', data.hostname || 'Unknown Device');
            
            const tunnelInput = document.getElementById('tunnelUrl');
            if (tunnelInput && data.tunnelUrl) {
                tunnelInput.value = data.tunnelUrl;
            }
        } catch (error) {
            this.showToast('Failed to load Telegram configuration', 'error');
        }
    }

    async saveTelegramConfig() {
        const botToken = document.getElementById('botToken').value.trim();
        const chatId = document.getElementById('chatId').value.trim();
        
        if (!botToken || !chatId) {
            this.showToast('Please fill in both Bot Token and Chat ID', 'warning');
            return;
        }

        try {
            await this.apiCallWithToast(
                this.config.apiEndpoints.updateTelegramConfig,
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ botToken, chatId })
                },
                'Telegram configuration saved successfully',
                'Failed to save Telegram configuration'
            );
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
            
            const result = JSON.parse(response);
            if (result.ok) {
                this.showToast('Test message sent successfully!', 'success');
            } else {
                this.showToast('Failed to send test message', 'error');
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
        }
    }

    copyTunnelUrl() {
        const tunnelInput = document.getElementById('tunnelUrl');
        if (tunnelInput && tunnelInput.value && tunnelInput.value !== '🔄 Waiting for URL...') {
            navigator.clipboard.writeText(tunnelInput.value).then(() => {
                this.showToast('Tunnel URL copied to clipboard!', 'success');
            }).catch(() => {
                this.showToast('Failed to copy URL', 'error');
            });
        } else {
            this.showToast('No tunnel URL available to copy', 'warning');
        }
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
            this.showToast('Failed to load version information', 'error');
        }
    }

    async checkForUpdates() {
        try {
            const response = await this.apiCall(this.config.apiEndpoints.checkUpdate);
            const data = JSON.parse(response);
            const currentVersion = document.getElementById('appVersion').textContent;
            
            if (data.version && data.version !== currentVersion) {
                this.showToast(
                    `Update available: v${data.version} <button onclick="app.doUpdate('${data.zipUrl}')" class="underline ml-2">Update Now</button>`,
                    'info',
                    10000
                );
            }
        } catch (error) {
            // Silently fail for update checks
        }
    }

    async doUpdate(url) {
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
    app = new V2RayMonitor();
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
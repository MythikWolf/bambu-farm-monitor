const API_BASE = '';

let printersConfig = [];

const PRINTER_MODELS = [
    { value: 'p1s', label: 'P1S' },
    { value: 'p1p', label: 'P1P' },
    { value: 'a1', label: 'A1' },
    { value: 'x1c', label: 'X1C' },
    { value: 'x1', label: 'X1' },
    { value: 'p2s', label: 'P2S' },
    { value: 'h2s', label: 'H2S' },
    { value: 'h2d', label: 'H2D' },
];

function modelOptions(selected) {
    return PRINTER_MODELS.map(m =>
        `<option value="${m.value}" ${m.value === selected ? 'selected' : ''}>${m.label}</option>`
    ).join('');
}

// Load printer configuration
async function loadPrinters() {
    try {
        const response = await fetch(`${API_BASE}/api/config/printers`);
        const data = await response.json();
        printersConfig = data.printers || [];
        renderPrinterForms();
    } catch (error) {
        console.error('Error loading printers:', error);
        showStatus('Failed to load printer configuration', 'error');
    }
}

// Render printer configuration forms
function renderPrinterForms() {
    const container = document.getElementById('printers-config');
    container.innerHTML = '';

    printersConfig.forEach(printer => {
        const card = document.createElement('div');
        card.className = 'printer-config-card';
        card.innerHTML = `
            <div class="printer-config-header">
                <h3>${printer.name}</h3>
                <span class="printer-number">Printer ${printer.id}</span>
                <button type="button" onclick="deletePrinter(${printer.id})" class="btn btn-delete" title="Delete Printer">
                    🗑️ Remove
                </button>
            </div>
            <form id="printer-form-${printer.id}">
                <div class="form-group">
                    <label for="name-${printer.id}">Printer Name</label>
                    <input type="text"
                           id="name-${printer.id}"
                           value="${printer.name}"
                           placeholder="e.g., Farm Printer #1">
                </div>
                <div class="form-row">
                    <div class="form-group">
                        <label for="ip-${printer.id}">IP Address</label>
                        <input type="text"
                               id="ip-${printer.id}"
                               value="${printer.ip}"
                               placeholder="e.g., 192.168.1.100"
                               pattern="^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$">
                    </div>
                    <div class="form-group">
                        <label for="code-${printer.id}">Access Code</label>
                        <input type="text"
                               id="code-${printer.id}"
                               value="${printer.access_code}"
                               placeholder="e.g., 12345678 or 922a6756">
                    </div>
                </div>
                <div class="form-row">
                    <div class="form-group">
                        <label for="model-${printer.id}">Printer Model</label>
                        <select id="model-${printer.id}">
                            ${modelOptions(printer.model || 'p1s')}
                        </select>
                    </div>
                    <div class="form-group">
                        <label for="serial-${printer.id}">Serial Number <span class="optional">(Optional - needed for MQTT status)</span></label>
                        <input type="text"
                               id="serial-${printer.id}"
                               value="${printer.serial || ''}"
                               placeholder="e.g., 01S00A000000000">
                    </div>
                </div>
                <div class="form-actions">
                    <button type="button" onclick="testMQTT(${printer.id})" class="btn btn-test">
                        🔌 Test MQTT Connection
                    </button>
                    <div id="mqtt-status-${printer.id}" class="mqtt-test-result"></div>
                </div>
            </form>
        `;
        container.appendChild(card);
    });

    // Add "Add Printer" button
    const addButton = document.createElement('div');
    addButton.className = 'add-printer-container';
    addButton.innerHTML = `
        <button type="button" onclick="addPrinter()" class="btn btn-add">
            ➕ Add Printer
        </button>
    `;
    container.appendChild(addButton);
}

// Add new printer
async function addPrinter() {
    showStatus('Adding new printer...', 'info');

    try {
        const maxId = printersConfig.length > 0 ? Math.max(...printersConfig.map(p => p.id)) : 0;
        const newId = maxId + 1;

        const response = await fetch(`${API_BASE}/api/config/printers`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                id: newId,
                name: `Printer ${newId}`,
                ip: '',
                access_code: '',
                serial: '',
                model: 'p1s'
            })
        });

        if (!response.ok) {
            throw new Error('Failed to add printer');
        }

        showStatus('✓ Printer added successfully!', 'success');
        await loadPrinters();

    } catch (error) {
        console.error('Error adding printer:', error);
        showStatus(`✗ Error: ${error.message}`, 'error');
    }
}

// Delete printer
async function deletePrinter(printerId) {
    if (!confirm(`Are you sure you want to delete Printer ${printerId}?`)) {
        return;
    }

    showStatus('Deleting printer...', 'info');

    try {
        const response = await fetch(`${API_BASE}/api/config/printers/${printerId}`, {
            method: 'DELETE'
        });

        if (!response.ok) {
            throw new Error('Failed to delete printer');
        }

        showStatus('✓ Printer deleted successfully!', 'success');

        await reconnectMQTT();
        await loadPrinters();

    } catch (error) {
        console.error('Error deleting printer:', error);
        showStatus(`✗ Error: ${error.message}`, 'error');
    }
}

// Save all printer configurations
async function saveAll() {
    showStatus('Saving changes...', 'info');

    try {
        for (const printer of printersConfig) {
            const name = document.getElementById(`name-${printer.id}`).value;
            const ip = document.getElementById(`ip-${printer.id}`).value;
            const code = document.getElementById(`code-${printer.id}`).value;
            const serial = document.getElementById(`serial-${printer.id}`).value;
            const model = document.getElementById(`model-${printer.id}`).value;

            if (!name || !ip || !code) {
                throw new Error(`Please fill all required fields for Printer ${printer.id}`);
            }

            const ipPattern = /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/;
            if (!ipPattern.test(ip)) {
                throw new Error(`Invalid IP address for Printer ${printer.id}`);
            }

            if (code.length < 6 || code.length > 16) {
                throw new Error(`Invalid access code for Printer ${printer.id} (must be 6-16 characters)`);
            }

            const response = await fetch(`${API_BASE}/api/config/printers/${printer.id}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    name: name,
                    ip: ip,
                    access_code: code,
                    serial: serial,
                    model: model
                })
            });

            if (!response.ok) {
                throw new Error(`Failed to update Printer ${printer.id}`);
            }
        }

        showStatus('✓ Configuration saved! Reloading streams...', 'success');

        await reconnectMQTT();
        await reloadConfig();

        setTimeout(() => {
            loadPrinters();
        }, 2000);

    } catch (error) {
        console.error('Error saving configuration:', error);
        showStatus(`✗ Error: ${error.message}`, 'error');
    }
}

// Reconnect MQTT connections
async function reconnectMQTT() {
    try {
        const response = await fetch(`${API_BASE}/api/status/reconnect`, {
            method: 'POST'
        });

        if (!response.ok) {
            throw new Error('Failed to reconnect MQTT');
        }

        const result = await response.json();
        console.log(`MQTT reconnected: ${result.mqtt_clients} clients`);

    } catch (error) {
        console.error('Error reconnecting MQTT:', error);
    }
}

// Reload go2rtc configuration
async function reloadConfig() {
    showStatus('Reloading configuration...', 'info');

    try {
        const response = await fetch(`${API_BASE}/api/config/reload`, {
            method: 'POST'
        });

        if (!response.ok) {
            throw new Error('Failed to reload configuration');
        }

        showStatus('✓ Configuration reloaded successfully!', 'success');

    } catch (error) {
        console.error('Error reloading configuration:', error);
        showStatus(`✗ Error: ${error.message}`, 'error');
    }
}

// Test MQTT connection for a printer
async function testMQTT(printerId) {
    const statusEl = document.getElementById(`mqtt-status-${printerId}`);
    statusEl.innerHTML = '<span class="testing">🔄 Testing MQTT connection...</span>';

    try {
        const name = document.getElementById(`name-${printerId}`).value;
        const ip = document.getElementById(`ip-${printerId}`).value;
        const code = document.getElementById(`code-${printerId}`).value;
        const serial = document.getElementById(`serial-${printerId}`).value;
        const model = document.getElementById(`model-${printerId}`).value;

        await fetch(`${API_BASE}/api/config/printers/${printerId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                name: name,
                ip: ip,
                access_code: code,
                serial: serial,
                model: model
            })
        });

        const response = await fetch(`${API_BASE}/api/status/mqtt-test/${printerId}`, {
            method: 'POST'
        });

        const result = await response.json();

        if (result.success) {
            statusEl.innerHTML = `
                <div class="mqtt-success">
                    ✅ <strong>Connected!</strong><br>
                    Topic: ${result.topic}<br>
                    ${result.message}
                </div>
            `;
        } else {
            let errorMsg = result.error || 'Unknown error';
            let helpText = '';

            if (result.connection_code === 7) {
                helpText = '<br><small>💡 Tip: Try adding the printer serial number above</small>';
            } else if (result.connection_code === 4) {
                helpText = '<br><small>💡 Tip: Check your access code is correct</small>';
            } else if (!result.connection_code) {
                helpText = '<br><small>💡 Tip: Verify printer IP and network connectivity</small>';
            }

            statusEl.innerHTML = `
                <div class="mqtt-error">
                    ❌ <strong>Connection Failed</strong><br>
                    ${errorMsg}${helpText}
                </div>
            `;
        }

    } catch (error) {
        statusEl.innerHTML = `
            <div class="mqtt-error">
                ❌ <strong>Error:</strong> ${error.message}
            </div>
        `;
    }
}

// Show status message
function showStatus(message, type) {
    const statusEl = document.getElementById('status-message');
    statusEl.textContent = message;
    statusEl.className = `status-message ${type}`;
    statusEl.classList.remove('hidden');

    if (type === 'success' || type === 'error') {
        setTimeout(() => {
            statusEl.classList.add('hidden');
        }, 5000);
    }
}

// Export configuration
async function exportConfig() {
    try {
        showStatus('📥 Exporting configuration...', 'info');
        window.location.href = `${API_BASE}/api/config/export`;
        setTimeout(() => {
            showStatus('✓ Configuration exported successfully!', 'success');
        }, 1000);
    } catch (error) {
        console.error('Error exporting configuration:', error);
        showStatus(`✗ Error: ${error.message}`, 'error');
    }
}

// Import configuration
async function importConfig(event) {
    const file = event.target.files[0];
    if (!file) return;

    if (!confirm('Are you sure you want to import this configuration? This will replace all current printer settings.')) {
        event.target.value = '';
        return;
    }

    showStatus('📤 Importing configuration...', 'info');

    try {
        const formData = new FormData();
        formData.append('file', file);

        const response = await fetch(`${API_BASE}/api/config/import`, {
            method: 'POST',
            body: formData
        });

        const result = await response.json();

        if (!response.ok) {
            throw new Error(result.error || 'Failed to import configuration');
        }

        showStatus(`✓ ${result.message}`, 'success');

        await reconnectMQTT();

        setTimeout(() => {
            loadPrinters();
        }, 2000);

    } catch (error) {
        console.error('Error importing configuration:', error);
        showStatus(`✗ Error: ${error.message}`, 'error');
    } finally {
        event.target.value = '';
    }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
    loadPrinters();
});

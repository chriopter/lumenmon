// Main dashboard view
// Coordinates data fetching, logging, and table rendering

let previousAgentCount = 0;

async function fetchAgents() {
    try {
        const response = await fetch('/api/agents');
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();

        // Render table
        renderTable(data.agents);

        // Log agent changes
        if (data.agents) {
            const currentCount = data.agents.length;
            if (previousAgentCount !== 0 && currentCount > previousAgentCount) {
                addLog(`agent connected (total: ${currentCount})`, 'success');
            } else if (previousAgentCount !== 0 && currentCount < previousAgentCount) {
                addLog(`agent disconnected (total: ${currentCount})`, 'error');
            }
            previousAgentCount = currentCount;
        }
    } catch (error) {
        console.error('Error:', error);
        document.getElementById('agents-container').innerHTML =
            `<div class="no-data">error: ${error.message}</div>`;
        addLog(`error fetching agents: ${error.message}`, 'error');
    }
}

async function createInvite() {
    const container = document.getElementById('invite-container-inline');
    container.innerHTML = '<span style="color: var(--foreground2);">...</span>';
    addLog('creating invite...', 'info');

    try {
        const response = await fetch('/api/invites/create', { method: 'POST' });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();

        if (data.success) {
            container.innerHTML = `
                <span class="invite-url-inline" onclick="copyToClipboard('${data.invite_url}')" title="click to copy">
                    ${data.invite_url}
                </span>
            `;
            addLog('invite created (valid 5 min)', 'success');
        } else {
            container.innerHTML = `<span style="color: var(--accent4);">error</span>`;
            addLog(`invite creation failed: ${data.error}`, 'error');
        }
    } catch (error) {
        console.error('Error:', error);
        container.innerHTML = `<span style="color: var(--accent4);">error</span>`;
        addLog(`invite creation error: ${error.message}`, 'error');
    }
}

function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(() => {
        const container = document.getElementById('invite-container-inline');
        const url = container.querySelector('.invite-url-inline');
        if (url) {
            const originalText = url.textContent;
            url.textContent = 'copied!';
            setTimeout(() => { url.textContent = originalText; }, 2000);
        }
        addLog('invite url copied to clipboard', 'info');
    }).catch(err => {
        console.error('Copy failed:', err);
        addLog('clipboard copy failed', 'error');
    });
}

// Logging system
function addLog(message, level = 'info') {
    const logEntries = document.getElementById('log-entries');
    const timestamp = new Date().toLocaleTimeString();
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.innerHTML = `<span class="log-timestamp">[${timestamp}]</span><span class="log-level-${level}">${message}</span>`;
    logEntries.appendChild(entry);

    // Auto-scroll to bottom
    const logBox = document.getElementById('log-box');
    logBox.scrollTop = logBox.scrollHeight;

    // Keep max 50 entries
    while (logEntries.children.length > 50) {
        logEntries.removeChild(logEntries.firstChild);
    }
}

// Initialize dashboard
function initDashboard() {
    addLog('console started', 'success');
    addLog('loading agents...', 'info');
    fetchAgents();
    setInterval(fetchAgents, 3000);
}

/**
 * Messages Widget - Shows emails for this host
 */

LumenmonWidget({
    name: 'messages',
    title: 'Mail',
    category: 'generic',
    metrics: [],  // No metrics, fetches from messages API
    size: 'stat',
    gridSize: 'sm',  // 2/4 width
    priority: 5,  // Show before CPU
    expandable: false,
    render: function(data, agent) {
        // Initial loading state - init() will populate
        return `
            <div class="tui-metric-box widget-messages" data-agent-id="${agent.id}">
                <div class="tui-metric-header">mail</div>
                <div class="widget-messages-list"></div>
            </div>
        `;
    },
    init: async function(el, data, agent) {
        await loadMessagesWidget(el, agent.id);
    },
    update: async function(el, data, agent) {
        await loadMessagesWidget(el, agent.id);
    }
});

// Format time as relative (now, 5m, 2h, 3d)
function formatMsgTime(dateStr) {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'now';
    if (diffMins < 60) return `${diffMins}m`;
    if (diffHours < 24) return `${diffHours}h`;
    if (diffDays < 7) return `${diffDays}d`;
    return date.toLocaleDateString('en', { month: 'short', day: 'numeric' });
}

// Load messages for a widget
async function loadMessagesWidget(el, agentId) {
    const container = el.querySelector('.widget-messages-list');
    if (!container) return;

    try {
        const response = await fetch(`/api/agents/${agentId}/messages?limit=5`);
        const result = await response.json();
        const messages = result.messages || [];

        if (messages.length === 0) {
            container.innerHTML = '<div class="widget-messages-empty">no mail</div>';
            // Update header (no badge)
            const header = el.querySelector('.tui-metric-header');
            if (header) header.innerHTML = 'mail';
            return;
        }

        let rows = '';
        messages.forEach((msg, i) => {
            const icon = msg.read ? '○' : '●';
            const readClass = msg.read ? 'mail-read' : 'mail-unread';
            const from = msg.mail_from.split('@')[0].substring(0, 8);
            const subject = msg.subject.substring(0, 14) + (msg.subject.length > 14 ? '…' : '');
            const time = formatMsgTime(msg.received_at);
            rows += `<div class="widget-msg-row ${readClass}" onclick="openMsgInWidget(${msg.id}, '${agentId}')">
                <span class="widget-msg-icon">${icon}</span>
                <span class="widget-msg-from">${from}</span>
                <span class="widget-msg-subject">${subject}</span>
                <span class="widget-msg-time">${time}</span>
            </div>`;
        });

        container.innerHTML = rows;

        // Update header with badge
        const unreadCount = messages.filter(m => !m.read).length;
        const badge = unreadCount > 0 ? `<span class="widget-msg-badge">${unreadCount}</span>` : '';
        const header = el.querySelector('.tui-metric-header');
        if (header) header.innerHTML = `mail ${badge}`;
    } catch (e) {
        container.innerHTML = '<div class="widget-messages-empty">error</div>';
    }
}

// Open message detail in a simple view
async function openMsgInWidget(messageId, agentId) {
    try {
        const response = await fetch(`/api/messages/${messageId}`);
        const msg = await response.json();

        const date = new Date(msg.received_at).toLocaleString();

        // Create a simple popup or replace widget content
        const overlay = document.createElement('div');
        overlay.className = 'msg-overlay';
        overlay.innerHTML = `
            <div class="msg-overlay-content tui-box">
                <div class="msg-overlay-header">
                    <span>${msg.subject || '(no subject)'}</span>
                    <span class="msg-overlay-close" onclick="this.parentElement.parentElement.parentElement.remove()">×</span>
                </div>
                <div class="msg-overlay-meta">
                    <div>FROM: ${msg.mail_from}</div>
                    <div>DATE: ${date}</div>
                </div>
                <div class="msg-overlay-body"><pre>${msg.body || '(empty)'}</pre></div>
                <div class="msg-overlay-actions">
                    <button onclick="deleteMsgFromWidget(${msg.id}, '${agentId}')" class="btn-tui btn-danger">delete</button>
                    <button onclick="this.closest('.msg-overlay').remove()" class="btn-tui">close</button>
                </div>
            </div>
        `;
        document.body.appendChild(overlay);

        // Refresh widgets to update read status
        if (typeof refreshDetailView === 'function') {
            setTimeout(refreshDetailView, 100);
        }
    } catch (e) {
        addLog(`Error: ${e.message}`, 'error');
    }
}

async function deleteMsgFromWidget(messageId, agentId) {
    try {
        await fetch(`/api/messages/${messageId}`, { method: 'DELETE' });
        document.querySelector('.msg-overlay')?.remove();
        addLog('message deleted', 'success');
        if (typeof refreshDetailView === 'function') {
            refreshDetailView();
        }
    } catch (e) {
        addLog(`Error: ${e.message}`, 'error');
    }
}

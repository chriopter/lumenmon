/**
 * Messages Widget - Shows emails for this host
 * Keyboard navigation: ↑↓ to navigate, Enter to open, d to delete, Esc to close
 */

// Track widget state per agent
const mailWidgetState = {};

LumenmonWidget({
    name: 'messages',
    title: 'Mail',
    category: 'generic',
    metrics: [],  // No metrics, fetches from messages API
    size: 'stat',
    gridSize: 'lg',  // Full width for more breathing room
    priority: 99,  // Last widget, right before ALL VALUES
    expandable: false,
    render: function(data, agent) {
        // Initial loading state - init() will populate
        return `
            <div class="tui-metric-box widget-messages" data-agent-id="${agent.id}" tabindex="0">
                <div class="tui-metric-header">mail</div>
                <div class="widget-messages-list"></div>
                <div class="widget-messages-expand"></div>
            </div>
        `;
    },
    init: async function(el, data, agent) {
        // Initialize state for this agent
        if (!mailWidgetState[agent.id]) {
            mailWidgetState[agent.id] = { selectedIndex: -1, messages: [], expandedId: null };
        }
        await loadMessagesWidget(el, agent.id);
        setupMailKeyboardNav(el, agent.id);
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
        const [messagesResponse, stalenessResponse] = await Promise.all([
            fetch(`/api/agents/${agentId}/messages?limit=10`),
            fetch('/api/messages/staleness')
        ]);
        const result = await messagesResponse.json();
        const staleness = stalenessResponse.ok ? await stalenessResponse.json() : { per_agent: [] };
        const messages = result.messages || [];
        const staleEntry = (staleness.per_agent || []).find(a => a.agent_id === agentId);
        const thresholdHours = Number(staleness.threshold_hours);
        const staleTitle = Number.isFinite(thresholdHours) && thresholdHours > 0
            ? (thresholdHours % 24 === 0
                ? `no mail for more than ${Math.floor(thresholdHours / 24)} days`
                : `no mail for more than ${thresholdHours} hours`)
            : 'no mail for more than 14 days';
        const staleBadge = staleEntry && staleEntry.is_stale ? `<span class="widget-msg-badge" title="${staleTitle}">stale</span>` : '';

        // Store messages for keyboard nav
        if (!mailWidgetState[agentId]) {
            mailWidgetState[agentId] = { selectedIndex: -1, messages: [], expandedId: null };
        }
        mailWidgetState[agentId].messages = messages;

        if (messages.length === 0) {
            container.innerHTML = '<div class="widget-messages-empty">no mail</div>';
            // Update header (no badge)
            const header = el.querySelector('.tui-metric-header');
            if (header) header.innerHTML = `mail ${staleBadge}`;
            return;
        }

        const state = mailWidgetState[agentId];
        let rows = '';
        messages.forEach((msg, i) => {
            const icon = msg.read ? '○' : '●';
            const readClass = msg.read ? 'mail-read' : 'mail-unread';
            const selectedClass = state.selectedIndex === i ? 'widget-msg-selected' : '';
            const from = msg.mail_from.split('@')[0].substring(0, 10);
            // Show full subject - no truncation for better visibility
            const subject = msg.subject || '(no subject)';
            const time = formatMsgTime(msg.received_at);
            rows += `<div class="widget-msg-row ${readClass} ${selectedClass}" data-msg-index="${i}" data-msg-id="${msg.id}" onclick="selectMailRow('${agentId}', ${i})">
                <span class="widget-msg-icon">${icon}</span>
                <span class="widget-msg-from">${from}</span>
                <span class="widget-msg-subject">${subject}</span>
                <span class="widget-msg-time">${time}</span>
            </div>`;
        });

        container.innerHTML = rows;

        // Update header with badge and hint
        const unreadCount = messages.filter(m => !m.read).length;
        const badge = unreadCount > 0 ? `<span class="widget-msg-badge">${unreadCount}</span>` : '';
        const header = el.querySelector('.tui-metric-header');
        if (header) header.innerHTML = `mail ${badge}${staleBadge}`;
    } catch (e) {
        container.innerHTML = '<div class="widget-messages-empty">error</div>';
    }
}

// Select a mail row (via click or keyboard)
function selectMailRow(agentId, index) {
    const state = mailWidgetState[agentId];
    if (!state) return;

    state.selectedIndex = index;

    // Update UI to show selection
    const widget = document.querySelector(`.widget-messages[data-agent-id="${agentId}"]`);
    if (!widget) return;

    widget.querySelectorAll('.widget-msg-row').forEach((row, i) => {
        row.classList.toggle('widget-msg-selected', i === index);
    });
}

// Setup keyboard navigation for mail widget
function setupMailKeyboardNav(el, agentId) {
    const widget = el.querySelector('.widget-messages');
    if (!widget) return;

    widget.addEventListener('keydown', async (e) => {
        const state = mailWidgetState[agentId];
        if (!state || state.messages.length === 0) return;

        switch (e.key) {
            case 'ArrowDown':
            case 'j':
                e.preventDefault();
                if (state.selectedIndex < state.messages.length - 1) {
                    selectMailRow(agentId, state.selectedIndex + 1);
                } else if (state.selectedIndex === -1) {
                    selectMailRow(agentId, 0);
                }
                break;

            case 'ArrowUp':
            case 'k':
                e.preventDefault();
                if (state.selectedIndex > 0) {
                    selectMailRow(agentId, state.selectedIndex - 1);
                } else if (state.selectedIndex === -1 && state.messages.length > 0) {
                    selectMailRow(agentId, state.messages.length - 1);
                }
                break;

            case 'Enter':
                e.preventDefault();
                if (state.selectedIndex >= 0 && state.selectedIndex < state.messages.length) {
                    const msg = state.messages[state.selectedIndex];
                    await expandMailInline(agentId, msg.id);
                }
                break;

            case 'd':
                e.preventDefault();
                await deleteSelectedMail(agentId);
                break;

            case 'Escape':
                e.preventDefault();
                closeMailExpand(agentId);
                break;
        }
    });

    // Focus widget on click
    widget.addEventListener('click', () => widget.focus());
}

async function deleteSelectedMail(agentId) {
    const state = mailWidgetState[agentId];
    if (!state || state.messages.length === 0) {
        addLog('no mail to delete', 'warning');
        return;
    }

    let selectedIndex = state.selectedIndex;
    if (selectedIndex < 0 || selectedIndex >= state.messages.length) {
        selectedIndex = state.expandedId
            ? state.messages.findIndex(m => m.id === state.expandedId)
            : 0;
    }

    if (selectedIndex < 0 || selectedIndex >= state.messages.length) {
        addLog('no mail selected', 'warning');
        return;
    }

    const message = state.messages[selectedIndex];

    try {
        const response = await fetch(`/api/messages/${message.id}`, { method: 'DELETE' });
        if (!response.ok) {
            let errorText = `HTTP ${response.status}`;
            try {
                const result = await response.json();
                if (result && result.error) {
                    errorText = result.error;
                }
            } catch (_) {}
            throw new Error(errorText);
        }

        addLog('message deleted', 'success');
        closeMailExpand(agentId);

        const widget = document.querySelector(`.widget-messages[data-agent-id="${agentId}"]`);
        if (!widget) {
            return;
        }

        await loadMessagesWidget(widget.parentElement, agentId);

        const refreshedState = mailWidgetState[agentId];
        if (!refreshedState || refreshedState.messages.length === 0) {
            if (refreshedState) {
                refreshedState.selectedIndex = -1;
            }
            return;
        }

        const nextIndex = Math.min(selectedIndex, refreshedState.messages.length - 1);
        selectMailRow(agentId, nextIndex);
    } catch (e) {
        addLog(`Error deleting message: ${e.message}`, 'error');
    }
}

// Expand mail inline below the widget (TUI style)
async function expandMailInline(agentId, messageId) {
    const widget = document.querySelector(`.widget-messages[data-agent-id="${agentId}"]`);
    if (!widget) return;

    const expandArea = widget.querySelector('.widget-messages-expand');
    if (!expandArea) return;

    const state = mailWidgetState[agentId];

    // Toggle off if same message
    if (state.expandedId === messageId) {
        closeMailExpand(agentId);
        return;
    }

    try {
        const response = await fetch(`/api/messages/${messageId}`);
        const msg = await response.json();

        const date = new Date(msg.received_at).toLocaleString();

        state.expandedId = messageId;

        expandArea.innerHTML = `
            <div class="mail-expand-content">
                <div class="mail-expand-header">
                    <span class="mail-expand-subject">${msg.subject || '(no subject)'}</span>
                </div>
                <div class="mail-expand-meta">
                    <div><span class="mail-meta-label">FROM</span> ${msg.mail_from}</div>
                    <div><span class="mail-meta-label">DATE</span> ${date}</div>
                </div>
                <div class="mail-expand-body"><pre>${msg.body || '(empty)'}</pre></div>
                <div class="mail-expand-actions">
                    <span class="mail-action" onclick="deleteMsgFromExpand(${msg.id}, '${agentId}')">delete</span>
                    <span class="mail-action" onclick="closeMailExpand('${agentId}')">close (esc)</span>
                </div>
            </div>
        `;
        expandArea.classList.add('open');

        // Refresh to update read status
        await loadMessagesWidget(widget.parentElement, agentId);

        // Restore selection
        const idx = state.messages.findIndex(m => m.id === messageId);
        if (idx >= 0) selectMailRow(agentId, idx);

        // Keep expanded
        state.expandedId = messageId;
        expandArea.querySelector('.mail-expand-content') && (expandArea.innerHTML = expandArea.innerHTML);

    } catch (e) {
        expandArea.innerHTML = '<div class="mail-expand-error">error loading message</div>';
    }
}

// Close expanded mail view
function closeMailExpand(agentId) {
    const widget = document.querySelector(`.widget-messages[data-agent-id="${agentId}"]`);
    if (!widget) return;

    const expandArea = widget.querySelector('.widget-messages-expand');
    if (expandArea) {
        expandArea.innerHTML = '';
        expandArea.classList.remove('open');
    }

    const state = mailWidgetState[agentId];
    if (state) state.expandedId = null;
}

// Delete from expanded view
async function deleteMsgFromExpand(messageId, agentId) {
    try {
        await fetch(`/api/messages/${messageId}`, { method: 'DELETE' });
        closeMailExpand(agentId);
        addLog('message deleted', 'success');

        const widget = document.querySelector(`.widget-messages[data-agent-id="${agentId}"]`);
        if (widget) {
            await loadMessagesWidget(widget.parentElement, agentId);
        }
    } catch (e) {
        addLog(`Error: ${e.message}`, 'error');
    }
}

// Open message detail - now uses inline expand
async function openMsgInWidget(messageId, agentId) {
    await expandMailInline(agentId, messageId);
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

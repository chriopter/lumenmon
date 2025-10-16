// Keyboard navigation for Lumenmon Console
// Provides TUI-style keyboard shortcuts

const KEYBOARD_SHORTCUTS = {
    'i': createInvite,
    'r': () => { fetchAgents(); showMessage('Refreshed agent list', 'success'); },
    'h': showHelp,
    '?': showHelp
};

let helpVisible = false;

function initKeyboardNavigation() {
    document.addEventListener('keydown', (e) => {
        // Ignore if typing in input field
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
            return;
        }

        const key = e.key.toLowerCase();

        // Handle help toggle
        if (key === 'h' || key === '?') {
            e.preventDefault();
            showHelp();
            return;
        }

        // Handle other shortcuts
        if (KEYBOARD_SHORTCUTS[key]) {
            e.preventDefault();
            KEYBOARD_SHORTCUTS[key]();
        }

        // ESC to close help or clear invite
        if (key === 'escape') {
            if (helpVisible) {
                closeHelp();
            } else {
                const inviteContainer = document.getElementById('invite-container');
                if (inviteContainer) inviteContainer.innerHTML = '';
            }
        }
    });
}

function showHelp() {
    if (helpVisible) {
        closeHelp();
        return;
    }

    helpVisible = true;
    const helpOverlay = document.createElement('div');
    helpOverlay.id = 'help-overlay';
    helpOverlay.innerHTML = `
        <div class="help-dialog">
            <h3>┌─ Keyboard Shortcuts ─┐</h3>
            <div class="shortcuts-list">
                <div class="shortcut"><kbd>i</kbd> Create invite</div>
                <div class="shortcut"><kbd>r</kbd> Refresh agents</div>
                <div class="shortcut"><kbd>h</kbd> or <kbd>?</kbd> Toggle help</div>
                <div class="shortcut"><kbd>ESC</kbd> Close dialogs</div>
            </div>
            <p class="help-footer">└─ Press ESC or any key to close ─┘</p>
        </div>
    `;
    document.body.appendChild(helpOverlay);

    // Close on any key or click
    const closeHandler = () => closeHelp();
    helpOverlay.addEventListener('click', closeHandler);
    document.addEventListener('keydown', closeHandler, { once: true });
}

function closeHelp() {
    helpVisible = false;
    const overlay = document.getElementById('help-overlay');
    if (overlay) {
        overlay.style.opacity = '0';
        setTimeout(() => overlay.remove(), 200);
    }
}

function showMessage(text, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = text;
    document.body.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => toast.remove(), 300);
    }, 2000);
}

// Initialize on load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initKeyboardNavigation);
} else {
    initKeyboardNavigation();
}

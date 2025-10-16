// Keyboard navigation for Lumenmon Console
// Simple TUI-style keyboard shortcuts

const KEYBOARD_SHORTCUTS = {
    'i': createInvite,
    'r': () => {
        fetchAgents();
        if (typeof addLog === 'function') addLog('manual refresh', 'info');
    },
    'h': showHelp
};

function initKeyboardNavigation() {
    document.addEventListener('keydown', (e) => {
        // Ignore if typing in input field
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
            return;
        }

        const key = e.key.toLowerCase();

        if (key === 'escape') {
            const inviteContainer = document.getElementById('invite-container-inline');
            if (inviteContainer) inviteContainer.innerHTML = '';
            return;
        }

        if (KEYBOARD_SHORTCUTS[key]) {
            e.preventDefault();
            KEYBOARD_SHORTCUTS[key]();
        }
    });
}

function showHelp() {
    alert('Keyboard Shortcuts:\n\ni - create invite\nr - refresh agents\nh - help\nesc - close');
}

// Initialize on load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initKeyboardNavigation);
} else {
    initKeyboardNavigation();
}

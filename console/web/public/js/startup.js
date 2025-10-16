// Lumenmon startup animation with ASCII logo
// Shows terminal boot sequence before loading main interface

const LUMENMON_LOGO = `
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
`;

const BOOT_MESSAGES = [
    '[ OK ] Starting Lumenmon Console...',
    '[ OK ] Loading SSH daemon...',
    '[ OK ] Initializing Flask API...',
    '[ OK ] Starting Caddy web server...',
    '[ OK ] Ready for agent connections',
    ''
];

function showStartupAnimation() {
    // Check if animation should be skipped
    if (sessionStorage.getItem('lumenmon_booted')) {
        return Promise.resolve();
    }

    return new Promise((resolve) => {
        const overlay = document.createElement('div');
        overlay.id = 'startup-overlay';
        overlay.innerHTML = `
            <div id="boot-screen">
                <pre id="logo-display"></pre>
                <div id="boot-messages"></div>
                <div id="boot-prompt">Press any key to skip...</div>
            </div>
        `;
        document.body.appendChild(overlay);

        const logoDisplay = document.getElementById('logo-display');
        const messagesDisplay = document.getElementById('boot-messages');
        let cancelled = false;

        // Skip on any key press
        const skipHandler = () => {
            cancelled = true;
            sessionStorage.setItem('lumenmon_booted', 'true');
            overlay.style.opacity = '0';
            setTimeout(() => {
                overlay.remove();
                resolve();
            }, 300);
        };
        document.addEventListener('keydown', skipHandler, { once: true });

        // Show logo with typing effect
        let logoIndex = 0;
        const logoInterval = setInterval(() => {
            if (cancelled) {
                clearInterval(logoInterval);
                return;
            }
            if (logoIndex < LUMENMON_LOGO.length) {
                logoDisplay.textContent += LUMENMON_LOGO[logoIndex];
                logoIndex++;
            } else {
                clearInterval(logoInterval);
                // Start boot messages
                showBootMessages();
            }
        }, 5);

        function showBootMessages() {
            let msgIndex = 0;
            const msgInterval = setInterval(() => {
                if (cancelled) {
                    clearInterval(msgInterval);
                    return;
                }
                if (msgIndex < BOOT_MESSAGES.length) {
                    const msg = document.createElement('div');
                    msg.textContent = BOOT_MESSAGES[msgIndex];
                    msg.style.color = '#a6e3a1'; // Green for OK messages
                    messagesDisplay.appendChild(msg);
                    msgIndex++;
                } else {
                    clearInterval(msgInterval);
                    // Auto-complete after last message
                    setTimeout(() => {
                        if (!cancelled) skipHandler();
                    }, 800);
                }
            }, 150);
        }
    });
}

// Auto-run on page load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        showStartupAnimation().then(() => {
            document.getElementById('main-interface')?.classList.remove('hidden');
        });
    });
} else {
    showStartupAnimation().then(() => {
        document.getElementById('main-interface')?.classList.remove('hidden');
    });
}

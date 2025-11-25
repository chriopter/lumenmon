/**
 * System Info Widget - Shows kernel and OS information
 */

LumenmonWidget({
    name: 'system_info',
    title: 'System',
    category: 'generic',
    metrics: ['generic_sys_kernel', 'generic_sys_os'],
    size: 'stat',
    render: function(data, agent) {
        const kernel = data['generic_sys_kernel']?.columns?.value || '-';
        const os = data['generic_sys_os']?.columns?.value || '-';

        return `
            <div class="stat-line">
                <span class="stat-label">KERNEL</span>
                <span class="stat-value">${kernel}</span>
            </div>
            <div class="stat-line">
                <span class="stat-label">OS</span>
                <span class="stat-value">${os}</span>
            </div>
        `;
    }
});

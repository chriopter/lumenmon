/**
 * System Info Widget - Shows kernel and OS information
 */

LumenmonWidget({
    name: 'system_info',
    title: 'System',
    category: 'generic',
    metrics: ['generic_sys_kernel', 'generic_sys_os'],
    size: 'stat',
    gridSize: 'sm',
    expandable: false,
    render: function(data, agent) {
        const kernel = data['generic_sys_kernel']?.columns?.value || '-';
        const os = data['generic_sys_os']?.columns?.value || '-';

        return `
            <div class="tui-metric-box tui-metric-box-info">
                <div class="tui-metric-header">system</div>
                <div class="tui-info-row">
                    <span class="tui-info-label">kernel</span>
                    <span class="tui-info-value">${kernel}</span>
                </div>
                <div class="tui-info-row">
                    <span class="tui-info-label">os</span>
                    <span class="tui-info-value">${os}</span>
                </div>
            </div>
        `;
    }
});

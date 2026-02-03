/**
 * System Info Widget - Shows kernel, OS, agent version, and updates
 */

LumenmonWidget({
    name: 'system_info',
    title: 'System',
    category: 'generic',
    metrics: ['generic_sys_kernel', 'generic_sys_os', 'generic_agent_version', 'debian_updates_total', 'debian_updates_security'],
    size: 'stat',
    gridSize: 'sm',  // 1/2 width
    priority: 2,  // Second widget (top right, same row as mail)
    render: function(data, agent) {
        const kernel = data['generic_sys_kernel']?.columns?.value || '-';
        const os = data['generic_sys_os']?.columns?.value || '-';
        const version = data['generic_agent_version']?.columns?.value || '-';
        const latest = window.app?.data?.latestVersion;

        // Check if agent outdated
        const isOutdated = version && version !== '-' && latest &&
            !version.startsWith(latest) && version !== latest;
        const versionClass = isOutdated ? 'status-warning' : '';

        // Updates info (if available)
        const updates = data['debian_updates_total']?.columns?.value;
        const security = data['debian_updates_security']?.columns?.value || 0;
        const hasUpdates = updates !== undefined;

        let updatesDisplay = '-';
        let updatesClass = '';
        if (hasUpdates) {
            if (updates === 0) {
                updatesDisplay = '✓ up to date';
            } else {
                updatesDisplay = `${updates} available`;
                if (security > 0) updatesDisplay += ` (${security} sec)`;
                updatesClass = 'status-warning';
            }
        }

        let html = `
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
                <div class="tui-info-row">
                    <span class="tui-info-label">agent</span>
                    <span class="tui-info-value ${versionClass}">${version}</span>
                </div>`;

        if (hasUpdates) {
            html += `
                <div class="tui-info-row">
                    <span class="tui-info-label">updates</span>
                    <span class="tui-info-value ${updatesClass}">${updatesDisplay}</span>
                </div>`;
        }

        html += `</div>`;
        return html;
    }
});

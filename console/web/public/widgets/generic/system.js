/**
 * System Info Widget - Shows kernel, OS, and agent version
 */

LumenmonWidget({
    name: 'system_info',
    title: 'System',
    category: 'generic',
    metrics: ['generic_sys_kernel', 'generic_sys_os', 'generic_agent_version'],
    size: 'stat',
    gridSize: 'sm',
    expandable: false,
    render: function(data, agent) {
        const kernel = data['generic_sys_kernel']?.columns?.value || '-';
        const os = data['generic_sys_os']?.columns?.value || '-';
        const version = data['generic_agent_version']?.columns?.value || '-';
        const latest = window.app?.data?.latestVersion;

        // Check if outdated (version exists, latest exists, and they differ)
        const isOutdated = version && version !== '-' && latest &&
            !version.startsWith(latest) && version !== latest;
        const versionClass = isOutdated ? 'status-warning' : '';
        const outdatedBadge = isOutdated ? ' <span class="tui-badge-warning">update</span>' : '';

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
                <div class="tui-info-row">
                    <span class="tui-info-label">agent</span>
                    <span class="tui-info-value ${versionClass}">${version}${outdatedBadge}</span>
                </div>
            </div>
        `;
    }
});

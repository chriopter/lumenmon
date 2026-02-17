/**
 * Proxmox Zpool Health Widget - shows degraded pools and upgrade-needed pools.
 */

LumenmonWidget({
    name: 'proxmox_zpool_health',
    title: 'Zpool Health',
    category: 'proxmox',
    metrics: ['proxmox_zpool_*'],
    size: 'stat',
    gridSize: 'sm',
    priority: 16,
    render: function(data) {
        const pools = {};

        Object.entries(data).forEach(([name, table]) => {
            const degradedMatch = name.match(/^proxmox_zpool_(.+)_degraded$/);
            if (degradedMatch) {
                const pool = degradedMatch[1];
                if (!pools[pool]) pools[pool] = {};
                pools[pool].degraded = Number(table.columns?.value || 0);
            }

            const upgradeMatch = name.match(/^proxmox_zpool_(.+)_upgrade_needed$/);
            if (upgradeMatch) {
                const pool = upgradeMatch[1];
                if (!pools[pool]) pools[pool] = {};
                pools[pool].upgradeNeeded = Number(table.columns?.value || 0);
            }
        });

        const entries = Object.entries(pools);
        if (entries.length === 0) {
            return '<div class="tui-box"><h3>zpool health</h3><span class="no-data">No zpool health data</span></div>';
        }

        let html = '<div class="tui-box"><h3>zpool health</h3><div class="tui-info-list">';
        entries.forEach(([pool, state]) => {
            const status = state.degraded ? 'DEGRADED' : 'online';
            const statusClass = state.degraded ? 'status-error' : 'status-ok';
            const upgradeHint = state.upgradeNeeded ? ' · upgrade needed' : '';
            html += `<div class="tui-info-row"><span class="tui-info-label">${pool.replace(/_/g, '-')}</span><span class="tui-info-value ${statusClass}">${status}${upgradeHint}</span></div>`;
        });
        html += '</div></div>';
        return html;
    }
});

/**
 * Proxmox ZFS Widget - Shows ZFS pool health, drive counts, and capacity
 */

LumenmonWidget({
    name: 'proxmox_zfs',
    title: 'ZFS Pools',
    category: 'proxmox',
    metrics: ['proxmox_zfs_*'],
    size: 'stat',
    gridSize: 'sm',
    expandable: false,
    render: function(data, agent) {
        // Group metrics by pool name
        const pools = {};

        Object.entries(data).forEach(([name, table]) => {
            const match = name.match(/^proxmox_zfs_(.+)_(drives|online|capacity)$/);
            if (match) {
                const poolName = match[1];
                const metric = match[2];
                if (!pools[poolName]) pools[poolName] = {};
                pools[poolName][metric] = table.columns?.value || 0;
            }
        });

        const poolList = Object.entries(pools);
        if (poolList.length === 0) {
            return '<div class="tui-box"><h3>zfs pools</h3><span class="no-data">No ZFS data</span></div>';
        }

        // ASCII bar helper
        const asciiBar = (percent, width = 10) => {
            const filled = Math.round((percent / 100) * width);
            const empty = width - filled;
            return '█'.repeat(filled) + '░'.repeat(empty);
        };

        let html = '<div class="tui-box"><h3>zfs pools</h3><div class="tui-zfs-list">';
        poolList.forEach(([name, p]) => {
            const drives = p.drives || 0;
            const online = p.online || 0;
            const capacity = p.capacity || 0;

            // Health status
            const healthy = drives === online;
            const healthIcon = healthy ? '●' : '⚠';
            const healthClass = healthy ? 'tui-health-ok' : 'tui-health-degraded';
            const healthText = healthy ? 'online' : 'DEGRADED';

            // Capacity bar color
            const barClass = capacity > 90 ? 'tui-bar-critical' : capacity > 70 ? 'tui-bar-warning' : 'tui-bar-ok';

            html += `<div class="tui-zfs-row">
                <span class="tui-zfs-name">${name.replace(/_/g, '-')}</span>
                <span class="tui-zfs-health ${healthClass}">${healthIcon} ${online}/${drives} ${healthText}</span>
                <span class="tui-zfs-bar ${barClass}">${asciiBar(capacity)}</span>
                <span class="tui-zfs-capacity">${capacity}%</span>
            </div>`;
        });
        html += '</div></div>';
        return html;
    }
});

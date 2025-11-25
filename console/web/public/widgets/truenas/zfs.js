/**
 * TrueNAS ZFS Widget - Shows ZFS pool health, drive counts, and capacity
 */

// Sparkline overview of all ZFS pools
LumenmonWidget({
    name: 'truenas_zfs_sparkline',
    title: 'ZFS',
    category: 'truenas',
    metrics: ['truenas_zfs_*'],
    size: 'sparkline',
    render: function(data, agent) {
        // Group metrics by pool name
        const pools = {};
        Object.entries(data).forEach(([name, table]) => {
            const match = name.match(/^truenas_zfs_(.+)_(drives|online|capacity)$/);
            if (match) {
                const poolName = match[1];
                const metric = match[2];
                if (!pools[poolName]) pools[poolName] = {};
                pools[poolName][metric] = table.columns?.value || 0;
            }
        });

        const poolList = Object.entries(pools);
        if (poolList.length === 0) {
            return '<span class="stat-label">ZFS</span><span class="stat-value">-</span>';
        }

        // Count total drives and online drives
        let totalDrives = 0;
        let onlineDrives = 0;
        let degradedPools = [];

        poolList.forEach(([name, p]) => {
            totalDrives += p.drives || 0;
            onlineDrives += p.online || 0;
            if ((p.drives || 0) !== (p.online || 0)) {
                degradedPools.push(name.replace(/_/g, '-'));
            }
        });

        const healthy = totalDrives === onlineDrives;
        const healthClass = healthy ? 'stat-ok' : 'stat-critical';
        const healthIcon = healthy ? '●' : '⚠';
        const statusText = healthy ? 'healthy' : `${degradedPools.join(', ')} degraded`;

        return `
            <span class="stat-label">ZFS</span>
            <span class="stat-value ${healthClass}">${healthIcon} ${onlineDrives}/${totalDrives}</span>
            <span class="stat-extra">${poolList.length} pools · ${statusText}</span>
        `;
    }
});

// Detailed table widget
LumenmonWidget({
    name: 'truenas_zfs',
    title: 'ZFS Pools',
    category: 'truenas',
    metrics: ['truenas_zfs_*'],
    size: 'table',
    render: function(data, agent) {
        // Group metrics by pool name
        const pools = {};

        Object.entries(data).forEach(([name, table]) => {
            const match = name.match(/^truenas_zfs_(.+)_(drives|online|capacity)$/);
            if (match) {
                const poolName = match[1];
                const metric = match[2];
                if (!pools[poolName]) pools[poolName] = {};
                pools[poolName][metric] = table.columns?.value || 0;
            }
        });

        const poolList = Object.entries(pools);
        if (poolList.length === 0) {
            return '<h4>ZFS Pools</h4><span class="no-data">No ZFS data</span>';
        }

        let html = '<h4>ZFS Pools</h4><table class="widget-table-inner"><thead><tr><td>POOL</td><td>HEALTH</td><td>CAPACITY</td></tr></thead><tbody>';
        poolList.forEach(([name, p]) => {
            const drives = p.drives || 0;
            const online = p.online || 0;
            const capacity = p.capacity || 0;

            // Health status
            const healthy = drives === online;
            const healthClass = healthy ? 'health-ok' : 'health-degraded';
            const healthText = healthy ? `${online}/${drives} online` : `${online}/${drives} DEGRADED`;

            // Capacity bar
            const barWidth = Math.min(capacity, 100);
            const barClass = capacity > 90 ? 'bar-critical' : capacity > 70 ? 'bar-warning' : 'bar-ok';

            html += `<tr>
                <td>${name.replace(/_/g, '-')}</td>
                <td class="${healthClass}">${healthText}</td>
                <td><span class="capacity-value">${capacity.toFixed(0)}%</span> <div class="usage-bar-inline ${barClass}" style="width: ${barWidth}%"></div></td>
            </tr>`;
        });
        html += '</tbody></table>';
        return html;
    }
});

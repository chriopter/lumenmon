/**
 * Proxmox ZFS Widget - Shows ZFS pool health, drive counts, and capacity
 */

LumenmonWidget({
    name: 'proxmox_zfs',
    title: 'ZFS Pools',
    category: 'proxmox',
    metrics: ['proxmox_zfs_*'],
    size: 'table',
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

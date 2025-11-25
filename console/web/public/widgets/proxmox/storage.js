/**
 * Proxmox Storage Widget - Shows storage pool usage
 */

LumenmonWidget({
    name: 'proxmox_storage',
    title: 'Storage',
    category: 'proxmox',
    metrics: ['proxmox_storage_*'],
    size: 'table',
    render: function(data, agent) {
        const pools = Object.entries(data)
            .filter(([name]) => name.startsWith('proxmox_storage_'))
            .map(([name, table]) => ({
                name: name.replace('proxmox_storage_', '').replace(/_/g, '-'),
                used: table.columns?.value || 0
            }));

        if (pools.length === 0) {
            return '<h4>Storage Pools</h4><span class="no-data">No storage data</span>';
        }

        let html = '<h4>Storage Pools</h4><table class="widget-table-inner"><thead><tr><td>POOL</td><td>USED</td><td></td></tr></thead><tbody>';
        pools.forEach(pool => {
            const barWidth = Math.min(pool.used, 100);
            const barClass = pool.used > 90 ? 'bar-critical' : pool.used > 70 ? 'bar-warning' : 'bar-ok';
            html += `<tr>
                <td>${pool.name}</td>
                <td>${pool.used.toFixed(1)}%</td>
                <td class="bar-cell"><div class="usage-bar ${barClass}" style="width: ${barWidth}%"></div></td>
            </tr>`;
        });
        html += '</tbody></table>';
        return html;
    }
});

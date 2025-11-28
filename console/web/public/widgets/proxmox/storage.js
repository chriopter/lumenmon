/**
 * Proxmox Storage Widget - Shows storage pool usage in TUI style
 */

LumenmonWidget({
    name: 'proxmox_storage',
    title: 'Storage',
    category: 'proxmox',
    metrics: ['proxmox_storage_*'],
    size: 'stat',
    gridSize: 'sm',
    expandable: false,
    render: function(data, agent) {
        // Group storage metrics by pool name (e.g., local, nas)
        const poolData = {};
        Object.entries(data).forEach(([name, table]) => {
            const match = name.match(/^proxmox_storage_(.+)_(total|used)$/);
            if (match) {
                const poolName = match[1];
                const metric = match[2];
                if (!poolData[poolName]) poolData[poolName] = {};
                poolData[poolName][metric] = table.columns?.value || 0;
            }
        });

        const pools = Object.entries(poolData);
        if (pools.length === 0) {
            return '<div class="tui-box"><h3>storage pools</h3><span class="no-data">No storage data</span></div>';
        }

        // ASCII bar helper
        const asciiBar = (percent, width = 12) => {
            const filled = Math.round((percent / 100) * width);
            const empty = width - filled;
            return '█'.repeat(filled) + '░'.repeat(empty);
        };

        let html = '<div class="tui-box"><h3>storage pools</h3><div class="tui-storage-list">';
        pools.forEach(([name, p]) => {
            const total = p.total || 0;
            const used = p.used || 0;
            const percent = total > 0 ? (used / total) * 100 : 0;
            const colorClass = percent > 90 ? 'tui-bar-critical' : percent > 70 ? 'tui-bar-warning' : 'tui-bar-ok';

            html += `<div class="tui-storage-row">
                <span class="tui-storage-name">${name.replace(/_/g, '-')}</span>
                <span class="tui-storage-bar ${colorClass}">${asciiBar(percent)}</span>
                <span class="tui-storage-info">${used} / ${total} GB</span>
            </div>`;
        });
        html += '</div></div>';
        return html;
    }
});

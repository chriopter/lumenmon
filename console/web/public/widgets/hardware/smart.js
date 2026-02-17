/**
 * Hardware SMART Widget - renders per-drive health and key SMART values.
 */

LumenmonWidget({
    name: 'hardware_smart',
    title: 'SMART',
    category: 'hardware',
    metrics: ['hardware_smart_*', 'hardware_samsung_*'],
    size: 'stat',
    gridSize: 'sm',
    priority: 15,
    render: function(data) {
        const drives = {};

        Object.entries(data).forEach(([name, table]) => {
            let m = name.match(/^hardware_smart_(.+)_(health|temp_c|wear_pct|power_cycles)$/);
            if (m) {
                const disk = m[1];
                const field = m[2];
                if (!drives[disk]) drives[disk] = {};
                drives[disk][field] = table.columns?.value;
                return;
            }

            m = name.match(/^hardware_samsung_(.+)_firmware$/);
            if (m) {
                const disk = m[1];
                if (!drives[disk]) drives[disk] = {};
                drives[disk].firmware = table.columns?.value;
            }
        });

        const entries = Object.entries(drives).sort((a, b) => a[0].localeCompare(b[0]));
        if (entries.length === 0) {
            return '<div class="tui-box"><h3>smart</h3><span class="no-data">No SMART data</span></div>';
        }

        let html = '<div class="tui-box"><h3>smart</h3><div class="tui-info-list">';
        entries.forEach(([disk, d]) => {
            let status = '/';
            let klass = '';
            if (d.health === 1 || d.health === '1') {
                status = 'ok';
                klass = 'status-ok';
            } else if (d.health === 0 || d.health === '0') {
                status = 'error';
                klass = 'status-error';
            }

            const temp = (d.temp_c !== undefined && d.temp_c !== null) ? `${d.temp_c}C` : '-';
            const wear = (d.wear_pct !== undefined && d.wear_pct !== null) ? ` wear:${d.wear_pct}%` : '';
            html += `<div class="tui-info-row"><span class="tui-info-label">${disk}</span><span class="tui-info-value ${klass}">${status} ${temp}${wear}</span></div>`;
        });
        html += '</div></div>';
        return html;
    }
});

/**
 * Hardware Temperatures Widget - renders per-sensor temperature with sparkline history.
 */

LumenmonWidget({
    name: 'hardware_temps',
    title: 'Hardware Temps',
    category: 'hardware',
    metrics: ['hardware_temp_*'],
    size: 'chart',
    gridSize: 'md',
    priority: 14,
    render: function(data) {
        const entries = Object.entries(data)
            .filter(([name]) => name.startsWith('hardware_temp_'))
            .sort((a, b) => a[0].localeCompare(b[0]));

        if (entries.length === 0) {
            return '<div class="tui-box"><h3>hardware temps</h3><span class="no-data">No temperature sensors</span></div>';
        }

        let html = '<div class="tui-box"><h3>hardware temps</h3><div class="tui-info-list">';
        entries.forEach(([metric, table]) => {
            const value = table.columns?.value;
            const valueText = (value !== null && value !== undefined) ? `${Number(value).toFixed(1)} C` : '-';
            const history = (table.history || []).map(p => Number(p.value)).filter(v => !Number.isNaN(v));
            const spark = history.length > 1 ? LumenmonWidgets.sparkline(history) : '...';

            const sensor = metric
                .replace(/^hardware_temp_/, '')
                .replace(/_c$/, '')
                .replace(/_/g, ' ');

            html += `<div class="tui-info-row"><span class="tui-info-label">${sensor}</span><span class="tui-info-value">${valueText}  ${spark}</span></div>`;
        });
        html += '</div></div>';
        return html;
    }
});

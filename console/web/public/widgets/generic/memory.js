/**
 * Memory Widget - Shows current memory usage with bar, expandable to full chart
 */

LumenmonWidget({
    name: 'memory_bar',
    title: 'Memory',
    category: 'generic',
    metrics: ['generic_memory'],
    size: 'sparkline',
    priority: 11,
    expandable: true,
    render: function(data, agent) {
        // Use current value from entities API or tables API
        const current = agent.memory ?? data['generic_memory']?.columns?.value ?? 0;
        const free = 100 - current;

        // ASCII bar (fills widget width)
        const barWidth = 12;
        const filled = Math.round((current / 100) * barWidth);
        const empty = barWidth - filled;
        const bar = '█'.repeat(filled) + '░'.repeat(empty);
        const barClass = current > 90 ? 'tui-bar-critical' : current > 70 ? 'tui-bar-warning' : 'tui-bar-ok';

        return `
            <div class="tui-metric-box">
                <div class="tui-metric-header">mem</div>
                <div class="tui-metric-value">${Number(current).toFixed(0)}<span class="tui-unit">%</span></div>
                <div class="tui-metric-bar ${barClass}">${bar}</div>
                <div class="tui-metric-extra">free ${Number(free).toFixed(0)}%</div>
                <span class="tui-expand-hint">enter</span>
            </div>
        `;
    },
    renderExpanded: function(data, agent) {
        const current = agent.memory ?? data['generic_memory']?.columns?.value ?? 0;
        const tableData = data['generic_memory'];
        const min = tableData?.columns?.min_value ?? 0;
        const max = tableData?.columns?.max_value ?? 100;
        const free = 100 - current;

        return `
            <div class="tui-metric-box">
                <div class="tui-metric-header">memory</div>
                <span class="tui-collapse-btn" title="collapse">esc ×</span>
                <div class="widget-expanded-stats">
                    <span>used: <strong>${Number(current).toFixed(1)}%</strong></span>
                    <span>free: <strong>${Number(free).toFixed(1)}%</strong></span>
                    <span>min: <strong>${min}</strong></span>
                    <span>max: <strong>${max}</strong></span>
                </div>
            </div>
        `;
    }
});

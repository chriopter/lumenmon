/**
 * CPU Widget - Shows current CPU usage with sparkline, expandable to full chart
 */

LumenmonWidget({
    name: 'cpu_sparkline',
    title: 'CPU',
    category: 'generic',
    metrics: ['generic_cpu'],
    size: 'sparkline',
    priority: 10,  // Show first
    expandable: true,
    render: function(data, agent) {
        // Use current value from entities API or tables API
        const current = agent.cpu ?? data['generic_cpu']?.columns?.value ?? 0;
        const sparkline = agent.cpuSparkline || '────────────';
        const barClass = current > 90 ? 'tui-bar-critical' : current > 70 ? 'tui-bar-warning' : 'tui-bar-ok';

        return `
            <div class="tui-metric-box">
                <div class="tui-metric-header">cpu</div>
                <div class="tui-metric-value">${Number(current).toFixed(0)}<span class="tui-unit">%</span></div>
                <div class="tui-metric-sparkline ${barClass}">${sparkline}</div>
                <div class="tui-metric-extra">avg ${Number(current).toFixed(0)}%</div>
                <span class="tui-expand-hint">enter</span>
            </div>
        `;
    },
    renderExpanded: function(data, agent) {
        const current = agent.cpu ?? data['generic_cpu']?.columns?.value ?? 0;
        const tableData = data['generic_cpu'];
        const min = tableData?.columns?.min_value ?? 0;
        const max = tableData?.columns?.max_value ?? 100;

        return `
            <div class="tui-metric-box">
                <div class="tui-metric-header">cpu</div>
                <span class="tui-collapse-btn" title="collapse">esc ×</span>
                <div class="widget-expanded-stats">
                    <span>current: <strong>${Number(current).toFixed(1)}%</strong></span>
                    <span>min: <strong>${min}</strong></span>
                    <span>max: <strong>${max}</strong></span>
                </div>
            </div>
        `;
    }
});

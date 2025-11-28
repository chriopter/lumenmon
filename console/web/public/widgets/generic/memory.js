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
        const memData = agent.memHistory || [];
        const current = memData.length > 0 ? memData[memData.length - 1].value : 0;
        const values = memData.map(h => h.value);
        const avg = values.length > 0 ? values.reduce((a, b) => a + b, 0) / values.length : 0;
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
                <div class="tui-metric-value">${current.toFixed(0)}<span class="tui-unit">%</span></div>
                <div class="tui-metric-bar ${barClass}">${bar}</div>
                <div class="tui-metric-extra">free ${free.toFixed(0)}%</div>
                <span class="tui-expand-hint">enter</span>
            </div>
        `;
    },
    renderExpanded: function(data, agent) {
        const memData = agent.memHistory || [];
        const current = memData.length > 0 ? memData[memData.length - 1].value : 0;
        const values = memData.map(h => h.value);
        const avg = values.length > 0 ? values.reduce((a, b) => a + b, 0) / values.length : 0;
        const max = values.length > 0 ? Math.max(...values) : 0;
        const min = values.length > 0 ? Math.min(...values) : 0;

        return `
            <div class="tui-metric-box">
                <div class="tui-metric-header">memory history</div>
                <span class="tui-collapse-btn" title="collapse">esc ×</span>
                <div class="widget-expanded-stats">
                    <span>current: <strong>${current.toFixed(1)}%</strong></span>
                    <span>avg: <strong>${avg.toFixed(1)}%</strong></span>
                    <span>max: <strong>${max.toFixed(1)}%</strong></span>
                    <span>min: <strong>${min.toFixed(1)}%</strong></span>
                </div>
                <div class="widget-chart-container">
                    <canvas id="mem-chart-expanded"></canvas>
                </div>
            </div>
        `;
    },
    initExpanded: function(container, data, agent, chartId) {
        if (agent.memHistory && agent.memHistory.length > 0) {
            window.renderMetricChart('mem-chart-expanded', 'Memory Usage', agent.memHistory, '#89b4fa', '%');
        }
    }
});

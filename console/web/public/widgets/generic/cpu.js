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
        const cpuData = agent.cpuHistory || [];
        const current = cpuData.length > 0 ? cpuData[cpuData.length - 1].value : 0;
        const values = cpuData.map(h => h.value);
        const avg = values.length > 0 ? values.reduce((a, b) => a + b, 0) / values.length : 0;
        const sparkline = LumenmonWidgets.sparkline(values.slice(-12));
        const barClass = current > 90 ? 'tui-bar-critical' : current > 70 ? 'tui-bar-warning' : 'tui-bar-ok';

        return `
            <div class="tui-metric-box">
                <div class="tui-metric-header">cpu</div>
                <div class="tui-metric-value">${current.toFixed(0)}<span class="tui-unit">%</span></div>
                <div class="tui-metric-sparkline ${barClass}">${sparkline || '────────────'}</div>
                <div class="tui-metric-extra">avg ${avg.toFixed(0)}%</div>
                <span class="tui-expand-hint">enter</span>
            </div>
        `;
    },
    renderExpanded: function(data, agent) {
        const cpuData = agent.cpuHistory || [];
        const current = cpuData.length > 0 ? cpuData[cpuData.length - 1].value : 0;
        const values = cpuData.map(h => h.value);
        const avg = values.length > 0 ? values.reduce((a, b) => a + b, 0) / values.length : 0;
        const max = values.length > 0 ? Math.max(...values) : 0;
        const min = values.length > 0 ? Math.min(...values) : 0;

        return `
            <div class="tui-metric-box">
                <div class="tui-metric-header">cpu history</div>
                <span class="tui-collapse-btn" title="collapse">esc ×</span>
                <div class="widget-expanded-stats">
                    <span>current: <strong>${current.toFixed(1)}%</strong></span>
                    <span>avg: <strong>${avg.toFixed(1)}%</strong></span>
                    <span>max: <strong>${max.toFixed(1)}%</strong></span>
                    <span>min: <strong>${min.toFixed(1)}%</strong></span>
                </div>
                <div class="widget-chart-container">
                    <canvas id="cpu-chart-expanded"></canvas>
                </div>
            </div>
        `;
    },
    initExpanded: function(container, data, agent, chartId) {
        if (agent.cpuHistory && agent.cpuHistory.length > 0) {
            window.renderMetricChart('cpu-chart-expanded', 'CPU Usage', agent.cpuHistory, '#a6e3a1', '%');
        }
    }
});

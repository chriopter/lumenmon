/**
 * Disk Widget - Shows current disk usage with sparkline, expandable to full chart
 */

LumenmonWidget({
    name: 'disk_sparkline',
    title: 'Disk',
    category: 'generic',
    metrics: ['generic_disk'],
    size: 'sparkline',
    priority: 12,  // Show third (after MEM)
    expandable: true,
    render: function(data, agent) {
        const diskData = agent.diskHistory || [];
        const current = diskData.length > 0 ? diskData[diskData.length - 1].value : 0;
        const values = diskData.map(h => h.value);
        const sparkline = LumenmonWidgets.sparkline(values.slice(-8));
        const free = 100 - current;
        const barClass = current > 90 ? 'tui-bar-critical' : current > 70 ? 'tui-bar-warning' : 'tui-bar-ok';

        return `
            <div class="tui-metric-box">
                <div class="tui-metric-header">disk</div>
                <div class="tui-metric-value">${current.toFixed(1)}%</div>
                <div class="tui-metric-sparkline ${barClass}">${sparkline || '────────'}</div>
                <div class="tui-metric-extra">free ${free.toFixed(1)}%</div>
                <span class="tui-expand-hint">enter</span>
            </div>
        `;
    },
    renderExpanded: function(data, agent) {
        const diskData = agent.diskHistory || [];
        const current = diskData.length > 0 ? diskData[diskData.length - 1].value : 0;
        const values = diskData.map(h => h.value);
        const free = 100 - current;
        const max = values.length > 0 ? Math.max(...values) : 0;
        const min = values.length > 0 ? Math.min(...values) : 0;

        return `
            <div class="tui-metric-box">
                <div class="tui-metric-header">disk history</div>
                <span class="tui-collapse-btn" title="collapse">esc ×</span>
                <div class="widget-expanded-stats">
                    <span>used: <strong>${current.toFixed(1)}%</strong></span>
                    <span>free: <strong>${free.toFixed(1)}%</strong></span>
                    <span>max: <strong>${max.toFixed(1)}%</strong></span>
                    <span>min: <strong>${min.toFixed(1)}%</strong></span>
                </div>
                <div class="widget-chart-container">
                    <canvas id="disk-chart-expanded"></canvas>
                </div>
            </div>
        `;
    },
    initExpanded: function(container, data, agent, chartId) {
        if (agent.diskHistory && agent.diskHistory.length > 0) {
            window.renderMetricChart('disk-chart-expanded', 'Disk Usage', agent.diskHistory, '#f9e2af', '%');
        }
    }
});

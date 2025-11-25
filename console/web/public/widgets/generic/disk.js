/**
 * Disk Widget - Shows current disk usage with sparkline and history chart
 */

// Sparkline widget (top overview)
LumenmonWidget({
    name: 'disk_sparkline',
    title: 'Disk',
    category: 'generic',
    metrics: ['generic_disk'],
    size: 'sparkline',
    render: function(data, agent) {
        const diskData = agent.diskHistory || [];
        const current = diskData.length > 0 ? diskData[diskData.length - 1].value : 0;
        const values = diskData.map(h => h.value);
        const sparkline = LumenmonWidgets.sparkline(values.slice(-8));
        const free = 100 - current;

        return `
            <span class="stat-label">DISK</span>
            <span class="stat-value">${current.toFixed(1)}%</span>
            <span class="sparkline">${sparkline}</span>
            <span class="stat-extra">free ${free.toFixed(1)}%</span>
        `;
    }
});

// Full chart widget
LumenmonWidget({
    name: 'disk_chart',
    title: 'Disk History',
    category: 'generic',
    metrics: ['generic_disk'],
    size: 'chart',
    render: function(data, agent) {
        return `
            <h3>disk history</h3>
            <canvas id="disk-chart"></canvas>
        `;
    },
    init: function(container, data, agent) {
        if (agent.diskHistory && agent.diskHistory.length > 0) {
            renderMetricChart('disk-chart', 'Disk Usage', agent.diskHistory, '#f9e2af', '%');
        }
    }
});

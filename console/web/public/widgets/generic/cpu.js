/**
 * CPU Widget - Shows current CPU usage with sparkline and history chart
 */

// Sparkline widget (top overview)
LumenmonWidget({
    name: 'cpu_sparkline',
    title: 'CPU',
    category: 'generic',
    metrics: ['generic_cpu'],
    size: 'sparkline',
    render: function(data, agent) {
        const cpuData = agent.cpuHistory || [];
        const current = cpuData.length > 0 ? cpuData[cpuData.length - 1].value : 0;
        const values = cpuData.map(h => h.value);
        const avg = values.length > 0 ? values.reduce((a, b) => a + b, 0) / values.length : 0;
        const sparkline = LumenmonWidgets.sparkline(values.slice(-8));

        return `
            <span class="stat-label">CPU</span>
            <span class="stat-value">${current.toFixed(1)}%</span>
            <span class="sparkline">${sparkline}</span>
            <span class="stat-extra">avg ${avg.toFixed(1)}%</span>
        `;
    }
});

// Full chart widget
LumenmonWidget({
    name: 'cpu_chart',
    title: 'CPU History',
    category: 'generic',
    metrics: ['generic_cpu'],
    size: 'chart',
    render: function(data, agent) {
        return `
            <h3>cpu history</h3>
            <canvas id="cpu-chart"></canvas>
        `;
    },
    init: function(container, data, agent) {
        if (agent.cpuHistory && agent.cpuHistory.length > 0) {
            renderMetricChart('cpu-chart', 'CPU Usage', agent.cpuHistory, '#a6e3a1', '%');
        }
    }
});

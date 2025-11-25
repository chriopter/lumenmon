/**
 * Memory Widget - Shows current memory usage with sparkline and history chart
 */

// Sparkline widget (top overview)
LumenmonWidget({
    name: 'memory_sparkline',
    title: 'Memory',
    category: 'generic',
    metrics: ['generic_memory'],
    size: 'sparkline',
    render: function(data, agent) {
        const memData = agent.memHistory || [];
        const current = memData.length > 0 ? memData[memData.length - 1].value : 0;
        const values = memData.map(h => h.value);
        const avg = values.length > 0 ? values.reduce((a, b) => a + b, 0) / values.length : 0;
        const sparkline = LumenmonWidgets.sparkline(values.slice(-8));

        return `
            <span class="stat-label">MEM</span>
            <span class="stat-value">${current.toFixed(1)}%</span>
            <span class="sparkline">${sparkline}</span>
            <span class="stat-extra">avg ${avg.toFixed(1)}%</span>
        `;
    }
});

// Full chart widget
LumenmonWidget({
    name: 'memory_chart',
    title: 'Memory History',
    category: 'generic',
    metrics: ['generic_memory'],
    size: 'chart',
    render: function(data, agent) {
        return `
            <h3>memory history</h3>
            <canvas id="mem-chart"></canvas>
        `;
    },
    init: function(container, data, agent) {
        if (agent.memHistory && agent.memHistory.length > 0) {
            renderMetricChart('mem-chart', 'Memory Usage', agent.memHistory, '#89b4fa', '%');
        }
    }
});

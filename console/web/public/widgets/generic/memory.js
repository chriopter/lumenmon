/**
 * Memory Widget - Shows current memory usage with inline chart
 */

LumenmonWidget({
    name: 'memory_chart',
    title: 'Memory',
    category: 'generic',
    metrics: ['generic_memory'],
    size: 'chart',
    gridSize: 'sm',
    priority: 11,
    expandable: false,
    render: function(data, agent) {
        const current = agent.memory ?? data['generic_memory']?.columns?.value ?? 0;
        const chartId = `chart-mem-${agent.id || 'default'}`;

        return `
            <div class="tui-metric-box tui-chart-widget">
                <div class="tui-chart-header">
                    <span class="tui-metric-header">mem</span>
                    <span class="tui-metric-value">${Number(current).toFixed(0)}<span class="tui-unit">%</span></span>
                </div>
                <div class="tui-chart-container">
                    <canvas id="${chartId}"></canvas>
                </div>
            </div>
        `;
    },
    init: function(el, data, agent) {
        const chartId = `chart-mem-${agent.id || 'default'}`;
        const history = agent.memHistory || [];
        const values = history.map(h => h.value);
        const labels = history.map((_, i) => '');

        const ctx = document.getElementById(chartId);
        if (!ctx) return;

        if (window.app.charts[chartId]) {
            window.app.charts[chartId].destroy();
        }

        window.app.charts[chartId] = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    data: values,
                    borderColor: getComputedStyle(document.documentElement).getPropertyValue('--blue').trim(),
                    backgroundColor: 'transparent',
                    borderWidth: 1.5,
                    tension: 0.3,
                    pointRadius: 0,
                    fill: false
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                animation: false,
                scales: {
                    y: {
                        min: 0,
                        max: 100,
                        display: false
                    },
                    x: {
                        display: false
                    }
                },
                plugins: {
                    legend: { display: false },
                    tooltip: { enabled: false }
                }
            }
        });
    }
});

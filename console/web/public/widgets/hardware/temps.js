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
        const toLabel = (metric) => {
            const raw = metric
                .replace(/^hardware_temp_/, '')
                .replace(/_c$/, '');

            const gpuMatch = raw.match(/^gpu_(\d+)$/);
            if (gpuMatch) return `gpu ${gpuMatch[1]}`;

            const nvmeMatch = raw.match(/^nvme_(.+)$/);
            if (nvmeMatch) {
                return `nvme ${nvmeMatch[1].replace(/__/g, '.')}`;
            }

            return raw
                .replace(/_/g, ' ')
                .replace(/\s+/g, ' ')
                .trim();
        };

        const scoreSensor = (sensor) => {
            const name = sensor.metric;
            let score = 0;

            if (name.includes('gpu_')) score += 120;
            if (name.includes('cpu_') || name.includes('package_id_0') || name.includes('cputin')) score += 105;
            if (name.includes('nvme_') || name.includes('composite')) score += 95;
            if (name.includes('systin')) score += 80;
            if (name.includes('pch_') || name.includes('chip_temp')) score += 75;
            if (name.includes('auxtin')) score -= 25;
            if (name.includes('core_')) score -= 20;
            if (name.endsWith('temp1')) score -= 10;

            return score;
        };

        const sensors = Object.entries(data)
            .filter(([name]) => name.startsWith('hardware_temp_'))
            .map(([metric, table]) => {
                const value = Number(table.columns?.value);
                const history = (table.history || []).map(p => Number(p.value)).filter(v => !Number.isNaN(v));
                return {
                    metric,
                    label: toLabel(metric),
                    value,
                    history,
                    score: Number.isNaN(value) ? -999 : scoreSensor({ metric })
                };
            })
            .filter(s => !Number.isNaN(s.value) && s.value >= -10 && s.value <= 120);

        if (sensors.length === 0) {
            return '<div class="tui-box"><h3>hardware temps</h3><span class="no-data">No temperature sensors</span></div>';
        }

        const keySensors = sensors
            .slice()
            .sort((a, b) => (b.score - a.score) || (b.value - a.value))
            .slice(0, 6);

        const hottest = sensors
            .slice()
            .sort((a, b) => b.value - a.value)
            .slice(0, 3);

        const selected = [];
        const seen = new Set();
        [...keySensors, ...hottest].forEach(sensor => {
            if (!seen.has(sensor.metric)) {
                seen.add(sensor.metric);
                selected.push(sensor);
            }
        });

        let html = '<div class="tui-box"><h3>hardware temps</h3><div class="tui-info-list">';
        selected.forEach((sensor) => {
            const valueText = `${sensor.value.toFixed(1)} C`;
            const history = sensor.history;
            const spark = history.length > 1 ? LumenmonWidgets.sparkline(history) : '...';
            const cls = sensor.value >= 85 ? 'status-error' : (sensor.value >= 75 ? 'status-warning' : '');
            html += `<div class="tui-info-row"><span class="tui-info-label">${sensor.label}</span><span class="tui-info-value ${cls}">${valueText}  ${spark}</span></div>`;
        });
        if (sensors.length > selected.length) {
            html += `<div class="tui-info-row"><span class="tui-info-label">sensors</span><span class="tui-info-value">showing ${selected.length}/${sensors.length}</span></div>`;
        }
        html += '</div></div>';
        return html;
    }
});

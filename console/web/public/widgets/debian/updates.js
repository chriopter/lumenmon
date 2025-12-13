/**
 * Debian/Ubuntu Updates Widget - Shows available updates
 */

LumenmonWidget({
    name: 'debian_updates',
    title: 'Updates',
    category: 'debian',
    metrics: ['debian_updates_total', 'debian_updates_security', 'debian_updates_release', 'debian_updates_age'],
    size: 'sparkline',
    gridSize: 'xs',  // 1-column width
    expandable: false,
    priority: 13,  // Show after CPU(10), Memory(11), Disk(12)
    render: function(data, agent) {
        const total = data['debian_updates_total']?.columns?.value || 0;
        const security = data['debian_updates_security']?.columns?.value || 0;
        const release = data['debian_updates_release']?.columns?.value || 0;
        const freshness = data['debian_updates_age']?.columns?.value;

        // Check health status for color (backend determines if out of bounds)
        const totalHealth = data['debian_updates_total']?.health || {};
        const freshnessHealth = data['debian_updates_age']?.health || {};

        // Determine overall status
        const hasUpdates = total > 0 || security > 0 || release > 0;
        const isStale = freshnessHealth.out_of_bounds || freshness > 24;

        // Choose appropriate color class
        let statusClass = 'health-ok';
        if (hasUpdates || isStale) statusClass = 'status-warning';

        // Build compact display for 1-column width
        let html = `
            <div class="tui-metric-box">
                <div class="tui-metric-header">update</div>
        `;

        if (!hasUpdates) {
            // Show checkmark and "0" when up to date
            html += `
                <div class="tui-metric-value ${statusClass}">0</div>
                <div class="tui-metric-sparkline">✓</div>
            `;
        } else {
            // Show count when updates available
            html += `
                <div class="tui-metric-value ${statusClass}">${total}</div>
            `;

            // Show type indicators in sparkline area
            if (security > 0 && release > 0) {
                html += `<div class="tui-metric-sparkline">sec+rel</div>`;
            } else if (security > 0) {
                html += `<div class="tui-metric-sparkline">${security} sec</div>`;
            } else if (release > 0) {
                html += `<div class="tui-metric-sparkline">release</div>`;
            } else {
                html += `<div class="tui-metric-sparkline">avail</div>`;
            }
        }

        html += `</div>`;
        return html;
    }
});
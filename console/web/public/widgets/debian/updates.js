/**
 * Debian/Ubuntu Updates Widget - Shows available updates
 */

LumenmonWidget({
    name: 'debian_updates',
    title: 'Updates',
    category: 'debian',
    metrics: ['debian_updates', 'debian_security_updates', 'debian_release_upgrade', 'debian_update_age'],
    size: 'stat',
    gridSize: 'sm',
    expandable: false,
    priority: 10,  // Show early (after CPU/Memory)
    render: function(data, agent) {
        const total = data['debian_updates']?.columns?.value || 0;
        const security = data['debian_security_updates']?.columns?.value || 0;
        const release = data['debian_release_upgrade']?.columns?.value || 0;
        const freshness = data['debian_update_age']?.columns?.value;

        // Check health status for color (backend determines if out of bounds)
        const totalHealth = data['debian_updates']?.health || {};
        const freshnessHealth = data['debian_update_age']?.health || {};

        // Determine overall status
        const hasUpdates = total > 0 || security > 0 || release > 0;
        const isStale = freshnessHealth.out_of_bounds || freshness > 24;

        // Choose appropriate color class
        let statusClass = 'health-ok';
        if (hasUpdates || isStale) statusClass = 'status-warning';

        // Build display
        let html = `
            <div class="tui-metric-box">
                <div class="tui-metric-header">updates</div>
        `;

        if (!hasUpdates) {
            html += `
                <div class="tui-metric-value ${statusClass}">${total}</div>
                <div class="tui-metric-extra">up to date</div>
            `;
        } else {
            html += `
                <div class="tui-metric-value ${statusClass}">${total}</div>
            `;

            // Show breakdown
            const details = [];
            if (security > 0) details.push(`${security} security`);
            if (release > 0) details.push('release upgrade');

            if (details.length > 0) {
                html += `<div class="tui-metric-extra">${details.join(', ')}</div>`;
            }
        }

        // Add stale indicator if package lists are old
        if (isStale && freshness !== undefined) {
            const ageText = freshness > 48 ? `${Math.floor(freshness/24)}d old` : `${freshness}h old`;
            html += `<div class="tui-metric-footer status-warning">⚠ lists ${ageText}</div>`;
        }

        html += `</div>`;
        return html;
    }
});
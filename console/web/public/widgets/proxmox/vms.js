/**
 * Proxmox VMs Widget - Shows VM counts (running/stopped/total)
 */

LumenmonWidget({
    name: 'proxmox_vms',
    title: 'VMs',
    category: 'proxmox',
    metrics: ['proxmox_vms_running', 'proxmox_vms_stopped', 'proxmox_vms_total'],
    size: 'stat',
    expandable: false,
    render: function(data, agent) {
        const running = data['proxmox_vms_running']?.columns?.value || 0;
        const stopped = data['proxmox_vms_stopped']?.columns?.value || 0;
        const total = data['proxmox_vms_total']?.columns?.value || 0;

        return `
            <div class="tui-metric-box tui-metric-box-wide">
                <div class="tui-metric-header">vms</div>
                <div class="tui-stat-grid">
                    <div class="tui-stat">
                        <span class="tui-stat-value tui-health-ok">${running}</span>
                        <span class="tui-stat-label">running</span>
                    </div>
                    <div class="tui-stat">
                        <span class="tui-stat-value tui-muted">${stopped}</span>
                        <span class="tui-stat-label">stopped</span>
                    </div>
                    <div class="tui-stat">
                        <span class="tui-stat-value">${total}</span>
                        <span class="tui-stat-label">total</span>
                    </div>
                </div>
            </div>
        `;
    }
});

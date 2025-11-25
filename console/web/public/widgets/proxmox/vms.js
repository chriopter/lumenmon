/**
 * Proxmox VMs Widget - Shows VM counts (running/stopped/total)
 */

LumenmonWidget({
    name: 'proxmox_vms',
    title: 'VMs',
    category: 'proxmox',
    metrics: ['proxmox_vms_running', 'proxmox_vms_stopped', 'proxmox_vms_total'],
    size: 'stat',
    render: function(data, agent) {
        const running = data['proxmox_vms_running']?.columns?.value || 0;
        const stopped = data['proxmox_vms_stopped']?.columns?.value || 0;
        const total = data['proxmox_vms_total']?.columns?.value || 0;

        return `
            <h4>VMs</h4>
            <div class="proxmox-stat-grid">
                <div class="proxmox-stat">
                    <span class="proxmox-stat-value running">${running}</span>
                    <span class="proxmox-stat-label">running</span>
                </div>
                <div class="proxmox-stat">
                    <span class="proxmox-stat-value stopped">${stopped}</span>
                    <span class="proxmox-stat-label">stopped</span>
                </div>
                <div class="proxmox-stat">
                    <span class="proxmox-stat-value">${total}</span>
                    <span class="proxmox-stat-label">total</span>
                </div>
            </div>
        `;
    }
});

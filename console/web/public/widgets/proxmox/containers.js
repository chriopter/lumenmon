/**
 * Proxmox Containers Widget - Shows LXC container counts (running/stopped/total)
 */

LumenmonWidget({
    name: 'proxmox_containers',
    title: 'Containers',
    category: 'proxmox',
    metrics: ['proxmox_ct_running', 'proxmox_ct_stopped', 'proxmox_ct_total'],
    size: 'stat',
    render: function(data, agent) {
        const running = data['proxmox_ct_running']?.columns?.value || 0;
        const stopped = data['proxmox_ct_stopped']?.columns?.value || 0;
        const total = data['proxmox_ct_total']?.columns?.value || 0;

        return `
            <h4>Containers</h4>
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

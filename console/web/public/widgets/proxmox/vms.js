/**
 * Proxmox VMs Widget - Shows VM counts (running/stopped/total)
 */

LumenmonWidget({
    name: 'proxmox_vms',
    title: 'VMs',
    category: 'proxmox',
    metrics: ['proxmox_vms_running', 'proxmox_vms_stopped', 'proxmox_vms_total'],
    size: 'stat',
    gridSize: 'xs',
    expandable: false,
    render: function(data, agent) {
        const running = data['proxmox_vms_running']?.columns?.value || 0;
        const stopped = data['proxmox_vms_stopped']?.columns?.value || 0;
        const total = data['proxmox_vms_total']?.columns?.value || 0;

        return `
            <div class="tui-metric-box">
                <div class="tui-metric-header">vms</div>
                <div class="tui-metric-value tui-health-ok">${running}<span class="tui-unit">/${total}</span></div>
                <div class="tui-metric-extra">${stopped} stopped</div>
            </div>
        `;
    }
});

/**
 * Proxmox Containers Widget - Shows LXC container counts (running/stopped/total)
 */

LumenmonWidget({
    name: 'proxmox_containers',
    title: 'Containers',
    category: 'proxmox',
    metrics: ['proxmox_containers_running', 'proxmox_containers_total'],
    size: 'stat',
    gridSize: 'xs',
    expandable: false,
    render: function(data, agent) {
        const running = data['proxmox_containers_running']?.columns?.value || 0;
        const total = data['proxmox_containers_total']?.columns?.value || 0;
        const stopped = total - running;

        return `
            <div class="tui-metric-box">
                <div class="tui-metric-header">lxc</div>
                <div class="tui-metric-value tui-health-ok">${running}<span class="tui-unit">/${total}</span></div>
                <div class="tui-metric-extra">${stopped} stopped</div>
            </div>
        `;
    }
});

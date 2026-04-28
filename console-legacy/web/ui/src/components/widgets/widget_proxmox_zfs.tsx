import type { AgentTable } from '../../types';

export function WidgetProxmoxZfs({ tables }: { tables: AgentTable[] }) {
    const zfsMap = new Map<string, { drives?: number; online?: number; capacity?: number }>();
    for (const table of tables) {
        const m = table.metric_name.match(/^proxmox_zfs_(.+)_(drives|online|capacity)$/);
        if (!m) continue;
        const name = m[1];
        const row = zfsMap.get(name) || {};
        row[m[2] as 'drives' | 'online' | 'capacity'] = Number(table.columns.value || 0);
        zfsMap.set(name, row);
    }
    const rows = Array.from(zfsMap.entries());
    if (!rows.length) return null;

    return (
        <article className="widget grid-sm">
            <div className="tui-metric-box">
                <div className="tui-metric-header">zfs pools</div>
                <div className="kv-list">
                    {rows.map(([name, row]) => {
                        const drives = row.drives || 0;
                        const online = row.online || 0;
                        const capacity = row.capacity || 0;
                        return (
                            <div key={name}>
                                <span>{name.replace(/_/g, '-')}</span>
                                <strong className={online < drives ? 'crit-text' : capacity > 90 ? 'warn-text' : 'ok-text'}>{online}/{drives} online · {capacity}% used</strong>
                            </div>
                        );
                    })}
                </div>
            </div>
        </article>
    );
}

import type { AgentTable } from '../../types';

export function WidgetProxmoxZpool({ tables }: { tables: AgentTable[] }) {
    const poolMap = new Map<string, { degraded?: number; upgradeNeeded?: number }>();
    for (const table of tables) {
        const degraded = table.metric_name.match(/^proxmox_zpool_(.+)_degraded$/);
        if (degraded) {
            const row = poolMap.get(degraded[1]) || {};
            row.degraded = Number(table.columns.value || 0);
            poolMap.set(degraded[1], row);
            continue;
        }
        const upgrade = table.metric_name.match(/^proxmox_zpool_(.+)_upgrade_needed$/);
        if (upgrade) {
            const row = poolMap.get(upgrade[1]) || {};
            row.upgradeNeeded = Number(table.columns.value || 0);
            poolMap.set(upgrade[1], row);
        }
    }

    const rows = Array.from(poolMap.entries());
    if (!rows.length) return null;

    return (
        <article className="widget grid-sm">
            <div className="tui-metric-box">
                <div className="tui-metric-header">zpool health</div>
                <div className="kv-list">
                    {rows.map(([name, row]) => (
                        <div key={name}>
                            <span>{name === 'any' ? 'any pool' : name.replace(/_/g, '-')}</span>
                            <strong className={row.degraded ? 'crit-text' : row.upgradeNeeded ? 'warn-text' : 'ok-text'}>{row.degraded ? 'degraded' : 'online'}{row.upgradeNeeded ? ' · upgrade needed' : ''}</strong>
                        </div>
                    ))}
                </div>
            </div>
        </article>
    );
}

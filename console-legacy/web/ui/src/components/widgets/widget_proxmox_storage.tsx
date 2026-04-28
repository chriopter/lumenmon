import type { AgentTable } from '../../types';

export function WidgetProxmoxStorage({ tables }: { tables: AgentTable[] }) {
    const poolMap = new Map<string, { used?: number; total?: number }>();
    for (const table of tables) {
        const m = table.metric_name.match(/^proxmox_storage_(.+)_(total|used)$/);
        if (!m) continue;
        const name = m[1];
        const row = poolMap.get(name) || {};
        row[m[2] as 'used' | 'total'] = Number(table.columns.value || 0);
        poolMap.set(name, row);
    }
    const rows = Array.from(poolMap.entries());
    if (!rows.length) return null;

    return (
        <article className="widget grid-sm">
            <div className="tui-metric-box">
                <div className="tui-metric-header">storage pools</div>
                <div className="kv-list">
                    {rows.map(([name, row]) => {
                        const used = row.used || 0;
                        const total = row.total || 0;
                        const pct = total > 0 ? Math.round((used / total) * 100) : 0;
                        return (
                            <div key={name}>
                                <span>{name.replace(/_/g, '-')}</span>
                                <strong className={pct > 90 ? 'crit-text' : pct > 70 ? 'warn-text' : 'ok-text'}>{used}/{total}GB ({pct}%)</strong>
                            </div>
                        );
                    })}
                </div>
            </div>
        </article>
    );
}

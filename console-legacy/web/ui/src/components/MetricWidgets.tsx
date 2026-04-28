import type { AgentTable } from '../types';
import { findMetricByPattern } from '../lib';
import { WidgetGenericCpu } from './widgets/widget_generic_cpu';
import { WidgetGenericDisk } from './widgets/widget_generic_disk';
import { WidgetGenericMemory } from './widgets/widget_generic_memory';
import { WidgetGenericSystem } from './widgets/widget_generic_system';
import { WidgetProxmoxStorage } from './widgets/widget_proxmox_storage';
import { WidgetProxmoxZfs } from './widgets/widget_proxmox_zfs';
import { WidgetProxmoxZpool } from './widgets/widget_proxmox_zpool';

type Props = {
    tables: AgentTable[];
    latestVersion: string;
    agentVersion: string;
};

function metricValue(table: AgentTable | undefined): string {
    if (!table) {
        return '-';
    }
    const raw = table.columns.value;
    return raw === null || raw === undefined ? '-' : String(raw);
}

export function MetricWidgets({ tables, latestVersion, agentVersion }: Props) {
    const cpu = tables.find((table) => table.metric_name === 'generic_cpu');
    const memory = tables.find((table) => table.metric_name === 'generic_memory');
    const disk = tables.find((table) => table.metric_name === 'generic_disk');
    const heartbeat = tables.find((table) => table.metric_name === 'generic_heartbeat');

    const kernel = tables.find((table) => table.metric_name === 'generic_sys_kernel');
    const os = tables.find((table) => table.metric_name === 'generic_sys_os');
    const updates = tables.find((table) => table.metric_name === 'debian_updates_total');
    const secUpdates = tables.find((table) => table.metric_name === 'debian_updates_security');

    const tempTables = findMetricByPattern(tables, /^hardware_temp_/);
    const smartTables = findMetricByPattern(tables, /^hardware_smart_/);

    const proxmoxVmsRunning = tables.find((table) => table.metric_name === 'proxmox_vms_running');
    const proxmoxVmsStopped = tables.find((table) => table.metric_name === 'proxmox_vms_stopped');
    const proxmoxContainersRunning =
        tables.find((table) => table.metric_name === 'proxmox_containers_running') ||
        tables.find((table) => table.metric_name === 'proxmox_cts_running');
    const proxmoxContainersStopped =
        tables.find((table) => table.metric_name === 'proxmox_containers_stopped') ||
        tables.find((table) => table.metric_name === 'proxmox_cts_stopped');

    const tempRows = tempTables
        .map((table) => ({
            name: table.metric_name.replace(/^hardware_temp_/, '').replace(/_c$/, '').replace(/_/g, ' '),
            value: Number(table.columns.value || 0)
        }))
        .filter((row) => row.value >= -10 && row.value <= 120)
        .sort((a, b) => b.value - a.value)
        .slice(0, 4);

    const smartRows = Array.from(
        smartTables.reduce((acc, table) => {
            const match = table.metric_name.match(/^hardware_smart_(.+)_(health|temp_c|wear_pct|power_cycles)$/);
            if (!match) {
                return acc;
            }
            const diskName = match[1];
            const key = match[2];
            const current = acc.get(diskName) || {};
            current[key] = table.columns.value;
            acc.set(diskName, current);
            return acc;
        }, new Map<string, Record<string, unknown>>())
    );

    return (
        <section className="widget-grid">
            <WidgetGenericCpu table={cpu} />
            <WidgetGenericMemory table={memory} />
            <WidgetGenericDisk table={disk} />
            <WidgetGenericSystem
                os={os}
                kernel={kernel}
                heartbeat={heartbeat}
                updates={updates}
                secUpdates={secUpdates}
                agentVersion={agentVersion}
                latestVersion={latestVersion}
            />

            {tempRows.length > 0 ? (
                <article className="widget grid-xs">
                    <div className="tui-metric-box">
                        <div className="tui-metric-header">hardware temps</div>
                        <div className="kv-list">
                            {tempRows.map((row) => (
                                <div key={row.name}>
                                    <span>{row.name}</span>
                                    <strong className={row.value > 85 ? 'crit-text' : row.value > 80 ? 'warn-text' : 'ok-text'}>
                                        {row.value.toFixed(1)} C
                                    </strong>
                                </div>
                            ))}
                        </div>
                    </div>
                </article>
            ) : null}

            {smartRows.length > 0 ? (
                <article className="widget grid-sm">
                    <div className="tui-metric-box">
                        <div className="tui-metric-header">smart</div>
                        <div className="kv-list">
                            {smartRows.map(([diskName, row]) => {
                                const health = Number(row.health ?? 1);
                                const temp = row.temp_c === undefined ? '-' : `${row.temp_c}C`;
                                const wear = row.wear_pct === undefined ? '-' : `${row.wear_pct}%`;
                                return (
                                    <div key={diskName}>
                                        <span>{diskName}</span>
                                        <strong className={health === 1 ? 'ok-text' : 'crit-text'}>
                                            {health === 1 ? `ok ${temp} wear:${wear}` : 'error'}
                                        </strong>
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                </article>
            ) : null}

            {proxmoxVmsRunning || proxmoxContainersRunning ? (
                <article className="widget grid-sm">
                    <div className="tui-metric-box">
                        <div className="tui-metric-header">proxmox runtime</div>
                        <div className="kv-list">
                            {proxmoxVmsRunning ? (
                                <div>
                                    <span>vms</span>
                                    <strong className="ok-text">
                                        {metricValue(proxmoxVmsRunning)} running / {metricValue(proxmoxVmsStopped)} stopped
                                    </strong>
                                </div>
                            ) : null}
                            {proxmoxContainersRunning ? (
                                <div>
                                    <span>containers</span>
                                    <strong className="ok-text">
                                        {metricValue(proxmoxContainersRunning)} running / {metricValue(proxmoxContainersStopped)} stopped
                                    </strong>
                                </div>
                            ) : null}
                        </div>
                    </div>
                </article>
            ) : null}

            <WidgetProxmoxStorage tables={tables} />
            <WidgetProxmoxZfs tables={tables} />
            <WidgetProxmoxZpool tables={tables} />
        </section>
    );
}

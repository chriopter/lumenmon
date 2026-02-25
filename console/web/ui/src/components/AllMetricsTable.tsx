import { useMemo } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { fetchJson } from '../api';
import { metricCurrentValue, toNumber } from '../lib';
import type { AgentTable } from '../types';

type Props = {
    agentId: string;
    tables: AgentTable[];
    latestVersion: string;
    onLog: (text: string) => void;
};

type PreparedMetric = {
    table: AgentTable;
    name: string;
    minClass: string;
    maxClass: string;
    rowClass: string;
    nextUpdateText: string;
    hasProblem: boolean;
    realClass: string;
    intClass: string;
    textClass: string;
};

function formatValue(value: number | string | null | undefined): string {
    if (value === null || value === undefined || value === '') {
        return '-';
    }
    return String(value);
}

function nextUpdateText(table: AgentTable): string {
    const interval = Number(table.columns.interval || 0);
    if (interval === 0) {
        return 'once';
    }
    const next = table.staleness?.next_update_in;
    if (!Number.isFinite(next)) {
        return '-';
    }
    const n = Number(next);
    if (n >= 0) {
        if (n < 60) {
            return `in ${n}s`;
        }
        if (n < 3600) {
            return `in ${Math.floor(n / 60)}m`;
        }
        return `in ${Math.floor(n / 3600)}h`;
    }
    const overdue = Math.abs(n);
    if (overdue < 60) {
        return `${overdue}s ago`;
    }
    if (overdue < 3600) {
        return `${Math.floor(overdue / 60)}m ago`;
    }
    return `${Math.floor(overdue / 3600)}h ago`;
}

export function AllMetricsTable({ agentId, tables, latestVersion, onLog }: Props) {
    const queryClient = useQueryClient();

    const prepared = useMemo(() => {
        return tables
            .map((table) => {
                const value = metricCurrentValue(table);
                const numericValue = toNumber(value);
                const maxValue = toNumber(table.columns.max_value);
                const minValue = toNumber(table.columns.min_value);
                const warnMax = toNumber(table.columns.warn_max_value);
                const warnMin = toNumber(table.columns.warn_min_value);
                const isOutdatedVersion =
                    table.metric_name === 'generic_agent_version' &&
                    !!latestVersion &&
                    !!value &&
                    String(value) !== latestVersion;

                const health = table.health || {
                    is_failed: false,
                    is_warning: false,
                    is_stale: false,
                    out_of_bounds: false,
                    warning_out_of_bounds: false
                };

                const hardProblem = health.is_failed || health.is_stale || health.out_of_bounds;
                const softProblem = health.is_warning || health.warning_out_of_bounds || isOutdatedVersion;
                const hasProblem = hardProblem || softProblem;

                let valueClass = '';
                let minClass = '';
                let maxClass = '';

                if (hardProblem) {
                    valueClass = 'crit-text';
                } else if (softProblem) {
                    valueClass = 'warn-text';
                }

                if (numericValue !== null) {
                    if (minValue !== null && numericValue < minValue) {
                        minClass = 'crit-text';
                    } else if (warnMin !== null && numericValue < warnMin) {
                        minClass = 'warn-text';
                    }
                    if (maxValue !== null && numericValue > maxValue) {
                        maxClass = 'crit-text';
                    } else if (warnMax !== null && numericValue > warnMax) {
                        maxClass = 'warn-text';
                    }
                }

                return {
                    table,
                    name: table.metric_name,
                    minClass,
                    maxClass,
                    rowClass: hardProblem ? 'metric-row-problem' : softProblem ? 'metric-row-warning' : '',
                    nextUpdateText: nextUpdateText(table),
                    hasProblem,
                    realClass: table.columns.value_real !== null ? valueClass : '',
                    intClass: table.columns.value_int !== null ? valueClass : '',
                    textClass: table.columns.value_text !== null ? valueClass : ''
                } satisfies PreparedMetric;
            })
            .sort((a, b) => a.name.localeCompare(b.name));
    }, [latestVersion, tables]);

    const problemMetrics = prepared.filter((metric) => metric.hasProblem);
    const orderedMetrics = [...prepared].sort((a, b) => {
        if (a.hasProblem && !b.hasProblem) return -1;
        if (!a.hasProblem && b.hasProblem) return 1;
        return a.name.localeCompare(b.name);
    });
    const collectors = useMemo(() => {
        const map = new Map<string, { total: number; failed: number; warning: number; stale: number }>();
        for (const table of tables) {
            const parts = table.metric_name.split('_');
            const collector = parts.length >= 2 ? `${parts[0]}_${parts[1]}` : parts[0];
            const row = map.get(collector) || { total: 0, failed: 0, warning: 0, stale: 0 };
            row.total += 1;
            if (table.health?.is_failed) row.failed += 1;
            if (table.health?.is_warning) row.warning += 1;
            if (table.health?.is_stale) row.stale += 1;
            map.set(collector, row);
        }
        return Array.from(map.entries()).sort((a, b) => a[0].localeCompare(b[0]));
    }, [tables]);

    async function deleteMetric(metricName: string) {
        const ok = window.confirm(`Delete metric "${metricName}"?`);
        if (!ok) {
            return;
        }
        try {
            await fetchJson<{ success: boolean; message?: string }>(`/api/agents/${agentId}/metrics/${metricName}`, {
                method: 'DELETE'
            });
            onLog(`deleted ${metricName}`);
            await queryClient.invalidateQueries({ queryKey: ['agent-tables', agentId] });
        } catch (error) {
            onLog(`delete failed: ${(error as Error).message}`);
        }
    }

    function renderTableHeader() {
        return (
            <thead>
                <tr>
                    <td>name</td>
                    <td>timestamp</td>
                    <td>real</td>
                    <td>int</td>
                    <td>text</td>
                    <td>min</td>
                    <td>max</td>
                    <td>interval</td>
                    <td>last update</td>
                    <td>next update</td>
                    <td>data span</td>
                    <td># samples</td>
                    <td></td>
                </tr>
            </thead>
        );
    }

    function renderRow(metric: PreparedMetric) {
        return (
            <tr key={metric.name} className={metric.rowClass}>
                <td className="mono-cell">{metric.name}</td>
                <td>{formatValue(metric.table.columns.timestamp)}</td>
                <td className={metric.realClass}>{formatValue(metric.table.columns.value_real)}</td>
                <td className={metric.intClass}>{formatValue(metric.table.columns.value_int)}</td>
                <td className={metric.textClass}>{formatValue(metric.table.columns.value_text)}</td>
                <td className={metric.minClass}>{formatValue(metric.table.columns.min_value)}</td>
                <td className={metric.maxClass}>{formatValue(metric.table.columns.max_value)}</td>
                <td>{formatValue(metric.table.columns.interval)}s</td>
                <td>{formatValue(metric.table.metadata?.timestamp_age)}</td>
                <td>{metric.nextUpdateText}</td>
                <td>{formatValue(metric.table.metadata?.data_span)}</td>
                <td>{formatValue(metric.table.metadata?.line_count)}</td>
                <td>
                    <button type="button" className="delete-metric" onClick={() => void deleteMetric(metric.name)}>x</button>
                </td>
            </tr>
        );
    }

    return (
        <section className="metrics-section">
            <h3 id="metrics-header">
                All Values{problemMetrics.length > 0 ? <span className="issues-badge">{` ⚠ ${problemMetrics.length}`}</span> : null}
            </h3>

            <div className="collectors-combined">
                <div className="collectors-combined-title">Collectors</div>
                <div className="collectors-combined-grid">
                    {collectors.map(([name, stats]) => (
                        <div key={name} className="collectors-combined-row">
                            <span>{name}</span>
                            <strong className={stats.failed > 0 ? 'crit-text' : stats.warning > 0 ? 'warn-text' : ''}>
                                {stats.total} · {stats.failed}f · {stats.warning}w · {stats.stale}s
                            </strong>
                        </div>
                    ))}
                </div>
            </div>

            <div className="metrics-table-wrap">
                <table className="tui-table">
                    {renderTableHeader()}
                    <tbody>
                        {orderedMetrics.map(renderRow)}
                    </tbody>
                </table>
            </div>
        </section>
    );
}

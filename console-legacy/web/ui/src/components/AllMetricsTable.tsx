import { useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { fetchJson } from '../api';
import { metricCurrentValue, toNumber } from '../lib';
import { MiniMetricChart } from './widgets/MiniMetricChart';
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
    rowClass: string;
    nextUpdateText: string;
    hasProblem: boolean;
    valueClass: string;
    statusText: string;
    statusClass: string;
    currentValueText: string;
    minClass: string;
    maxClass: string;
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
    const [expandedMetric, setExpandedMetric] = useState<string | null>(null);

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
                let statusText = 'ok';
                let statusClass = 'ok-text';

                if (hardProblem) {
                    valueClass = 'crit-text';
                    statusText = health.is_stale ? 'stale' : 'failed';
                    statusClass = 'crit-text';
                } else if (softProblem) {
                    valueClass = 'warn-text';
                    statusText = 'warning';
                    statusClass = 'warn-text';
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
                    rowClass: hardProblem ? 'metric-row-problem' : softProblem ? 'metric-row-warning' : '',
                    nextUpdateText: nextUpdateText(table),
                    hasProblem,
                    valueClass,
                    statusText,
                    statusClass,
                    currentValueText: formatValue(metricCurrentValue(table)),
                    minClass,
                    maxClass
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

    function renderHistory(metric: PreparedMetric) {
        const numericHistory = (metric.table.history || []).filter((point) => Number.isFinite(point.value));
        if (numericHistory.length < 2) {
            return <div className="metric-history-empty">No numeric history available.</div>;
        }

        return (
            <div className="metric-history-chart">
                <MiniMetricChart
                    points={numericHistory}
                    color={metric.statusClass === 'crit-text' ? '#f38ba8' : metric.statusClass === 'warn-text' ? '#f9e2af' : '#a6e3a1'}
                    yMin={toNumber(metric.table.columns.min_value) ?? undefined}
                    yMax={toNumber(metric.table.columns.max_value) ?? undefined}
                />
            </div>
        );
    }

    function renderRow(metric: PreparedMetric) {
        const expanded = expandedMetric === metric.name;
        const boundsClass = metric.minClass === 'crit-text' || metric.maxClass === 'crit-text'
            ? 'crit-text'
            : metric.minClass === 'warn-text' || metric.maxClass === 'warn-text'
                ? 'warn-text'
                : '';
        return (
            <article key={metric.name} className={`metric-card ${metric.rowClass}`}>
                <div className="metric-row">
                    <button
                        type="button"
                        className="metric-toggle"
                        onClick={() => setExpandedMetric(expanded ? null : metric.name)}
                    >
                        <span className="metric-cell metric-name mono-cell">{metric.name}</span>
                        <span className={`metric-cell metric-value ${metric.valueClass}`}>{metric.currentValueText}</span>
                        <span className={`metric-cell metric-bounds ${boundsClass}`}>
                            {formatValue(metric.table.columns.min_value)}..{formatValue(metric.table.columns.max_value)}
                        </span>
                        <span className="metric-cell metric-next">{metric.nextUpdateText}</span>
                        <span className={`metric-cell metric-status ${metric.statusClass}`}>{metric.statusText}</span>
                    </button>
                    <button type="button" className="delete-metric" onClick={() => void deleteMetric(metric.name)}>x</button>
                </div>

                {expanded ? (
                    <div className="metric-expand">
                        {renderHistory(metric)}
                        <div className="metric-meta-grid">
                            <div><span>timestamp</span><strong>{formatValue(metric.table.columns.timestamp)}</strong></div>
                            <div><span>real</span><strong className={metric.valueClass}>{formatValue(metric.table.columns.value_real)}</strong></div>
                            <div><span>int</span><strong className={metric.valueClass}>{formatValue(metric.table.columns.value_int)}</strong></div>
                            <div><span>text</span><strong className={metric.valueClass}>{formatValue(metric.table.columns.value_text)}</strong></div>
                            <div><span>interval</span><strong>{formatValue(metric.table.columns.interval)}s</strong></div>
                            <div><span>last update</span><strong>{formatValue(metric.table.metadata?.timestamp_age)}</strong></div>
                            <div><span>next update</span><strong>{metric.nextUpdateText}</strong></div>
                            <div><span>data span</span><strong>{formatValue(metric.table.metadata?.data_span)}</strong></div>
                            <div><span>samples</span><strong>{formatValue(metric.table.metadata?.line_count)}</strong></div>
                        </div>
                    </div>
                ) : null}
            </article>
        );
    }

    return (
        <section className="metrics-section">
            <h3 id="metrics-header">
                All Values{problemMetrics.length > 0 ? <span className="issues-badge">{` ⚠ ${problemMetrics.length}`}</span> : null}
            </h3>

            <div className="metrics-table-wrap">
                <div className="metrics-headline-row">
                    <span>name</span>
                    <span>value</span>
                    <span>bounds</span>
                    <span>next</span>
                    <span>state</span>
                </div>
                <div className="metrics-list">
                    {orderedMetrics.map(renderRow)}
                </div>
            </div>
        </section>
    );
}

import type { AgentTable } from '../../types';
import { metricCurrentValue } from '../../lib';
import { MiniMetricChart } from './MiniMetricChart';

export function WidgetGenericDisk({ table }: { table?: AgentTable }) {
    if (!table) return null;
    const value = Number(metricCurrentValue(table) || 0);
    const warn = table.columns.warn_max_value ?? null;
    const crit = table.columns.max_value ?? null;
    const tone = crit !== null && value > Number(crit)
        ? 'crit-text'
        : warn !== null && value > Number(warn)
            ? 'warn-text'
            : 'ok-text';

    return (
        <article className="widget grid-xs widget-compact">
            <div className="tui-metric-box">
                <div className="tui-metric-header">disk</div>
                <div className={`tui-metric-value ${tone}`}>{value.toFixed(1)}<span className="tui-unit">%</span></div>
                <MiniMetricChart points={table.history || []} color={tone === 'crit-text' ? '#f38ba8' : tone === 'warn-text' ? '#f9e2af' : '#a6e3a1'} unit="%" yMin={0} yMax={100} />
            </div>
        </article>
    );
}

import type { AgentTable } from '../../types';
import { metricCurrentValue } from '../../lib';

type Props = {
    os?: AgentTable;
    kernel?: AgentTable;
    heartbeat?: AgentTable;
    updates?: AgentTable;
    secUpdates?: AgentTable;
    agentVersion: string;
    latestVersion: string;
};

export function WidgetGenericSystem({
    os,
    kernel,
    heartbeat,
    updates,
    secUpdates,
    agentVersion,
    latestVersion
}: Props) {
    const safeValue = (table?: AgentTable) => (table ? metricCurrentValue(table) : '-');
    const updatesValue = Number((updates ? metricCurrentValue(updates) : 0) || 0);
    const sec = Number((secUpdates ? metricCurrentValue(secUpdates) : 0) || 0);
    const outdated = !!latestVersion && !!agentVersion && latestVersion !== agentVersion;
    return (
        <article className="widget grid-xs widget-system-compact">
            <div className="tui-metric-box">
                <div className="tui-metric-header">system</div>
                <div className="kv-list">
                    <div><span>os</span><strong className="ok-text">{safeValue(os)}</strong></div>
                    <div><span>kernel</span><strong className="ok-text">{safeValue(kernel)}</strong></div>
                    <div><span>agent</span><strong className={outdated ? 'warn-text' : 'ok-text'}>{agentVersion || '-'}</strong></div>
                    <div><span>updates</span><strong className={updatesValue > 0 ? 'warn-text' : 'ok-text'}>{updatesValue > 0 ? `${updatesValue}/${sec}s` : 'ok'}</strong></div>
                    <div><span>hb</span><strong className="ok-text">{safeValue(heartbeat)}</strong></div>
                </div>
            </div>
        </article>
    );
}

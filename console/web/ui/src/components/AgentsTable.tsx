import { useState } from 'react';
import { displayName, formatRelativeAge } from '../lib';
import type { Entity } from '../types';
import { HostSparkline } from './HostSparkline';

type Props = {
    entities: Entity[];
    staleMailMap: Record<string, boolean>;
    selectedAgentId: string | null;
    onSelect: (id: string) => void;
    onReorder: (orderedAgentIds: string[]) => void;
    showIndex?: boolean;
};

function statusClass(entity: Entity, staleMailMap: Record<string, boolean>): string {
    if (entity.type === 'invite') {
        return entity.valid ? 'online' : 'offline';
    }
    if (entity.status === 'offline') {
        return 'offline';
    }
    if ((entity.failed_collectors || 0) > 0) {
        return 'critical';
    }
    if (entity.mail_only || entity.is_mail_only) {
        return 'warning';
    }
    if (staleMailMap[entity.id] || (entity.warning_collectors || 0) > 0) {
        return 'degraded';
    }
    return entity.status || 'online';
}

export function AgentsTable({ entities, staleMailMap, selectedAgentId, onSelect, onReorder, showIndex = false }: Props) {
    const [dragSourceId, setDragSourceId] = useState<string | null>(null);

    const sorted = [...entities];
    const oneHourCutoff = (Date.now() / 1000) - 3600;
    const globalSparkMax = Math.max(
        1,
        ...sorted.flatMap((entity) => {
            const points = entity.cpuHistory?.length
                ? entity.cpuHistory
                : entity.memHistory?.length
                    ? entity.memHistory
                    : entity.diskHistory?.length
                        ? entity.diskHistory
                        : [];
            return points.filter((point) => point.timestamp >= oneHourCutoff).map((point) => Number(point.value || 0));
        })
    );

    function handleDrop(targetId: string) {
        if (!dragSourceId || dragSourceId === targetId) {
            setDragSourceId(null);
            return;
        }
        const movable = sorted.filter((entity) => entity.type !== 'invite').map((entity) => entity.id);
        const fromIndex = movable.indexOf(dragSourceId);
        const toIndex = movable.indexOf(targetId);
        if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) {
            setDragSourceId(null);
            return;
        }
        const next = [...movable];
        const [item] = next.splice(fromIndex, 1);
        next.splice(toIndex, 0, item);
        onReorder(next);
        setDragSourceId(null);
    }

    return (
        <section className="agents-section">
            <div className="table-wrap">
                <table id="agents-table">
                    <thead>
                        <tr>
                            <td>hostname</td>
                            <td>spark</td>
                            <td>cpu</td>
                            <td>mem</td>
                            <td>disk</td>
                        </tr>
                    </thead>
                    <tbody>
                        {sorted.map((entity, rowIndex) => {
                            const selected = selectedAgentId === entity.id;
                            const issues = (entity.failed_collectors || 0) + (entity.warning_collectors || 0) + (staleMailMap[entity.id] ? 1 : 0);
                            const sparkPoints =
                                entity.cpuHistory?.length
                                    ? entity.cpuHistory
                                    : entity.memHistory?.length
                                        ? entity.memHistory
                                        : entity.diskHistory?.length
                                            ? entity.diskHistory
                                            : [];
                            return (
                                <tr
                                    key={entity.id}
                                    className={`agent-row ${selected ? 'selected' : ''}`}
                                    onClick={() => onSelect(entity.id)}
                                    draggable={entity.type !== 'invite'}
                                    onDragStart={() => setDragSourceId(entity.id)}
                                    onDragOver={(event) => {
                                        if (entity.type !== 'invite') {
                                            event.preventDefault();
                                        }
                                    }}
                                    onDrop={() => handleDrop(entity.id)}
                                    onDragEnd={() => setDragSourceId(null)}
                                >
                                    <td>
                                        <div className="agent-name">
                                            <span className={`status-dot ${statusClass(entity, staleMailMap)}`} />
                                            {showIndex ? `${rowIndex + 1}. ` : ''}{displayName(entity)}{issues > 0 && entity.type !== 'invite' ? <span className="issues-inline">({issues})</span> : null}
                                        </div>
                                    </td>
                                    <td>
                                        <HostSparkline points={sparkPoints} yMax={globalSparkMax} />
                                    </td>
                                    <td>{entity.type === 'invite' ? '-' : `${Math.round(entity.cpu || 0)}%`}</td>
                                    <td>{entity.type === 'invite' ? '-' : `${Math.round(entity.memory || 0)}%`}</td>
                                    <td title={entity.type === 'invite' ? '' : `age: ${formatRelativeAge(entity.age || 0)}`}>{entity.type === 'invite' ? '-' : `${Math.round(entity.disk || 0)}%`}</td>
                                </tr>
                            );
                        })}
                    </tbody>
                </table>
            </div>
        </section>
    );
}

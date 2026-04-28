import type { AgentTable, Entity, Message } from './types';

export function displayName(entity: Entity): string {
    return entity.display_name || entity.hostname || entity.original_hostname || entity.id;
}

export function formatRelativeAge(seconds: number | null | undefined): string {
    if (!Number.isFinite(seconds)) {
        return '-';
    }
    const value = Number(seconds);
    if (value < 60) {
        return `${value}s`;
    }
    if (value < 3600) {
        return `${Math.floor(value / 60)}m`;
    }
    if (value < 86400) {
        return `${Math.floor(value / 3600)}h`;
    }
    return `${Math.floor(value / 86400)}d`;
}

export function formatMessageTime(value: string): string {
    const date = new Date(value);
    const diffMs = Date.now() - date.getTime();
    const minutes = Math.floor(diffMs / 60000);
    const hours = Math.floor(diffMs / 3600000);
    const days = Math.floor(diffMs / 86400000);
    if (minutes < 1) {
        return 'now';
    }
    if (minutes < 60) {
        return `${minutes}m`;
    }
    if (hours < 24) {
        return `${hours}h`;
    }
    if (days < 7) {
        return `${days}d`;
    }
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function metricTitle(metricName: string): string {
    switch (metricName) {
        case 'generic_cpu':
            return 'CPU';
        case 'generic_memory':
            return 'Memory';
        case 'generic_disk':
            return 'Disk';
        case 'generic_heartbeat':
            return 'Heartbeat';
        default:
            return metricName;
    }
}

export function severityRank(entity: Entity, staleMailMap: Record<string, boolean>): number {
    if (entity.type === 'invite') {
        return 4;
    }
    if (entity.status === 'offline') {
        return 0;
    }
    if ((entity.failed_collectors || 0) > 0) {
        return 1;
    }
    if (staleMailMap[entity.id] || (entity.warning_collectors || 0) > 0 || entity.status === 'degraded') {
        return 2;
    }
    if (entity.mail_only || entity.is_mail_only) {
        return 3;
    }
    return 5;
}

export function toNumber(value: number | string | null | undefined): number | null {
    if (value === null || value === undefined) {
        return null;
    }
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
}

export function findMetric(tables: AgentTable[], metricName: string): AgentTable | undefined {
    return tables.find((table) => table.metric_name === metricName);
}

export function findMetricByPattern(tables: AgentTable[], pattern: RegExp): AgentTable[] {
    return tables.filter((table) => pattern.test(table.metric_name));
}

export function isAgentEntity(entity: Entity | null): entity is Entity {
    if (!entity) {
        return false;
    }
    return entity.type !== 'invite';
}

export function emailLocalPart(message: Message): string {
    return (message.mail_from || '').split('@')[0] || 'sender';
}

export function sparklineFromPoints(values: Array<number | null | undefined>): string {
    const clean = values.filter((value): value is number => Number.isFinite(value));
    if (!clean.length) {
        return '';
    }
    const blocks = ['_', '.', ':', '-', '=', '+', '*', '#'];
    const min = Math.min(...clean);
    const max = Math.max(...clean);
    const range = max - min || 1;
    return clean
        .slice(-20)
        .map((value) => {
            const normalized = (value - min) / range;
            const index = Math.max(0, Math.min(blocks.length - 1, Math.floor(normalized * (blocks.length - 1))));
            return blocks[index];
        })
        .join('');
}

export function metricCurrentValue(table: AgentTable): number | string | null {
    if (table.columns.value !== undefined) {
        return table.columns.value;
    }
    if (table.columns.value_real !== undefined && table.columns.value_real !== null) {
        return table.columns.value_real;
    }
    if (table.columns.value_int !== undefined && table.columns.value_int !== null) {
        return table.columns.value_int;
    }
    if (table.columns.value_text !== undefined && table.columns.value_text !== null) {
        return table.columns.value_text;
    }
    return null;
}

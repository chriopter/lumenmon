import type {
    AgentTablesResponse,
    AlertStatusResponse,
    CollectorCoverageResponse,
    EntitiesResponse,
    InviteCreateResponse,
    LatestVersionResponse,
    Message,
    MessageListResponse,
    StalenessResponse,
    UnreadResponse
} from './types';

export async function fetchJson<T>(url: string, init?: RequestInit): Promise<T> {
    const response = await fetch(url, init);
    if (!response.ok) {
        throw new Error(`HTTP ${response.status} ${url}`);
    }
    return response.json() as Promise<T>;
}

export function fetchEntities(): Promise<EntitiesResponse> {
    return fetchJson<EntitiesResponse>('/api/entities');
}

export function fetchAgentTables(agentId: string): Promise<AgentTablesResponse> {
    return fetchJson<AgentTablesResponse>(`/api/agents/${agentId}/tables`);
}

export function fetchUnreadCounts(): Promise<UnreadResponse> {
    return fetchJson<UnreadResponse>('/api/messages/unread-counts');
}

export function fetchMailStaleness(): Promise<StalenessResponse> {
    return fetchJson<StalenessResponse>('/api/messages/staleness');
}

export function fetchAlertStatus(): Promise<AlertStatusResponse> {
    return fetchJson<AlertStatusResponse>('/api/alerts/status');
}

export function fetchLatestVersion(): Promise<LatestVersionResponse> {
    return fetchJson<LatestVersionResponse>('/api/version/latest');
}

export function fetchCollectorCoverage(): Promise<CollectorCoverageResponse> {
    return fetchJson<CollectorCoverageResponse>('/api/collectors/coverage');
}

export function createInvite(): Promise<InviteCreateResponse> {
    return fetchJson<InviteCreateResponse>('/api/invites/create/full', { method: 'POST' });
}

export function deleteAgent(agentId: string): Promise<{ success: boolean; message?: string }> {
    return fetchJson<{ success: boolean; message?: string }>(`/api/agents/${agentId}`, { method: 'DELETE' });
}

export function resetAgent(agentId: string): Promise<{ success: boolean; message?: string }> {
    return fetchJson<{ success: boolean; message?: string }>(`/api/agents/${agentId}/reset`, { method: 'POST' });
}

export function updateAgentName(agentId: string, name: string): Promise<{ success: boolean }> {
    return fetchJson<{ success: boolean }>(`/api/agents/${agentId}/name`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name })
    });
}

export function fetchAgentEmail(agentId: string): Promise<{ email: string }> {
    return fetchJson<{ email: string }>(`/api/agents/${agentId}/email`);
}

export function fetchAgentMessages(agentId: string): Promise<MessageListResponse> {
    return fetchJson<MessageListResponse>(`/api/agents/${agentId}/messages?limit=10`);
}

export function fetchAllMessages(limit = 10): Promise<MessageListResponse> {
    return fetchJson<MessageListResponse>(`/api/messages?limit=${limit}`);
}

export function reorderAgents(agentIds: string[]): Promise<{ success?: boolean }> {
    return fetchJson<{ success?: boolean }>('/api/agents/reorder', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ agent_ids: agentIds })
    });
}

export function fetchMessage(messageId: number): Promise<Message> {
    return fetchJson<Message>(`/api/messages/${messageId}`);
}

export function deleteMessage(messageId: number): Promise<{ success: boolean }> {
    return fetchJson<{ success: boolean }>(`/api/messages/${messageId}`, { method: 'DELETE' });
}

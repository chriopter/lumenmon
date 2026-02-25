export type MetricPoint = {
    timestamp: number;
    value: number;
};

export type Entity = {
    id: string;
    type: 'agent' | 'invite';
    status?: string;
    hostname?: string;
    display_name?: string | null;
    original_hostname?: string;
    valid?: boolean;
    mail_only?: boolean;
    is_mail_only?: boolean;
    cpu?: number;
    memory?: number;
    disk?: number;
    failed_collectors?: number;
    warning_collectors?: number;
    total_collectors?: number;
    age?: number;
    uptime?: string;
    heartbeat?: number;
    agent_version?: string;
    cpuHistory?: Array<{ timestamp: number; value: number }>;
    memHistory?: Array<{ timestamp: number; value: number }>;
    diskHistory?: Array<{ timestamp: number; value: number }>;
    pending_invite?: {
        username?: string;
        invite_url?: string;
        install_command?: string;
        email_address?: string;
    } | null;
    has_mqtt_user?: boolean;
    has_table?: boolean;
    group?: string | null;
    group_order?: number;
};

export type EntitiesResponse = {
    entities: Entity[];
    count: number;
    timestamp: number;
};

export type AgentTable = {
    metric_name: string;
    columns: {
        timestamp?: number;
        value: number | string | null;
        value_real?: number | null;
        value_int?: number | null;
        value_text?: string | null;
        interval: number;
        min_value: number | null;
        max_value: number | null;
        warn_min_value: number | null;
        warn_max_value: number | null;
    };
    metadata?: {
        timestamp_age?: string;
        data_span?: string;
        line_count?: number;
    };
    history: MetricPoint[];
    staleness: {
        age: number;
        is_stale: boolean;
        next_update_in: number;
    };
    health: {
        is_failed: boolean;
        is_warning: boolean;
        is_stale: boolean;
        out_of_bounds: boolean;
        warning_out_of_bounds: boolean;
    };
};

export type CollectorCoverageResponse = {
    collectors: Array<{
        collector: string;
        status: 'has_data' | 'no_data' | 'event_only';
        patterns: string[];
        matched_metrics: string[];
        agents_count: number;
        coverage_pct: number;
        agents_with_data: Array<{ id: string; name: string }>;
    }>;
    summary: {
        total_collectors: number;
        metric_collectors: number;
        metric_collectors_with_data: number;
        metric_collectors_without_data: number;
        event_only_collectors: number;
        agents_seen: number;
    };
};

export type AgentTablesResponse = {
    tables: AgentTable[];
};

export type UnreadResponse = {
    counts: Record<string, number>;
};

export type StalenessResponse = {
    threshold_hours: number;
    per_agent: Array<{
        agent_id: string;
        is_stale: boolean;
        age_hours?: number | null;
    }>;
};

export type AlertStatusResponse = {
    configured: boolean;
    enabled: boolean;
    mode: string;
};

export type InviteCreateResponse = {
    success: boolean;
    username?: string;
    invite_url?: string;
    install_command?: string;
    email_address?: string;
    error?: string;
};

export type Message = {
    id: number;
    agent_id: string | null;
    mail_from: string;
    mail_to: string;
    subject: string;
    body?: string;
    received_at: string;
    read: boolean;
};

export type MessageListResponse = {
    messages: Message[];
};

export type LatestVersionResponse = {
    version: string;
};

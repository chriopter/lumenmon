import { useEffect, useMemo, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import {
    createInvite,
    deleteAgent,
    fetchAgentEmail,
    fetchAgentTables,
    fetchAlertStatus,
    fetchEntities,
    fetchLatestVersion,
    fetchMailStaleness,
    fetchUnreadCounts,
    reorderAgents,
    resetAgent,
    updateAgentName
} from './api';
import { AgentsTable } from './components/AgentsTable';
import { AllMetricsTable } from './components/AllMetricsTable';
import { LoggerPanel } from './components/LoggerPanel';
import { MessagesWidget } from './components/MessagesWidget';
import { MetricWidgets } from './components/MetricWidgets';
import { displayName, isAgentEntity } from './lib';
import type { Entity, InviteCreateResponse } from './types';

type LogEntry = {
    id: number;
    text: string;
    ts: string;
};

type InviteModalState = {
    open: boolean;
    payload: InviteCreateResponse | null;
};

function readAgentFromHash(): string | null {
    const hash = window.location.hash;
    if (hash.startsWith('#agent=')) {
        return hash.replace('#agent=', '');
    }
    return null;
}

export function App() {
    const queryClient = useQueryClient();
    const [selectedAgentId, setSelectedAgentId] = useState<string | null>(readAgentFromHash());
    const [detailOpen, setDetailOpen] = useState(true);
    const [logs, setLogs] = useState<LogEntry[]>(() => [
        { id: 1, text: 'console started', ts: new Date().toLocaleTimeString('en-US', { hour12: false }) }
    ]);
    const [inviteModal, setInviteModal] = useState<InviteModalState>({ open: false, payload: null });

    const entitiesQuery = useQuery({
        queryKey: ['entities'],
        queryFn: fetchEntities,
        refetchInterval: 2000
    });

    const unreadQuery = useQuery({
        queryKey: ['unread-counts'],
        queryFn: fetchUnreadCounts,
        refetchInterval: 15000
    });

    const stalenessQuery = useQuery({
        queryKey: ['mail-staleness'],
        queryFn: fetchMailStaleness,
        refetchInterval: 60000
    });

    const alertsQuery = useQuery({
        queryKey: ['alerts-status'],
        queryFn: fetchAlertStatus,
        refetchInterval: 60000
    });

    const latestVersionQuery = useQuery({
        queryKey: ['latest-version'],
        queryFn: fetchLatestVersion,
        retry: false,
        refetchInterval: 3600000
    });

    const entities = entitiesQuery.data?.entities || [];

    const staleMailMap = useMemo(() => {
        const map: Record<string, boolean> = {};
        for (const row of stalenessQuery.data?.per_agent || []) {
            map[row.agent_id] = row.is_stale;
        }
        return map;
    }, [stalenessQuery.data?.per_agent]);

    const sortedEntities = useMemo(() => {
        return [...entities].sort((a, b) => {
            const aInvite = a.type === 'invite' ? 1 : 0;
            const bInvite = b.type === 'invite' ? 1 : 0;
            if (aInvite !== bInvite) {
                return aInvite - bInvite;
            }

            const aGroup = a.group || '';
            const bGroup = b.group || '';
            if (aGroup !== bGroup) {
                if (!aGroup) return 1;
                if (!bGroup) return -1;
                return aGroup.localeCompare(bGroup);
            }

            const aOrder = Number(a.group_order || 0);
            const bOrder = Number(b.group_order || 0);
            if (aOrder !== bOrder) {
                return aOrder - bOrder;
            }
            return displayName(a).toLowerCase().localeCompare(displayName(b).toLowerCase());
        });
    }, [entities]);

    useEffect(() => {
        if (!sortedEntities.length) {
            setSelectedAgentId(null);
            return;
        }
        if (!selectedAgentId || !sortedEntities.some((entity) => entity.id === selectedAgentId)) {
            setSelectedAgentId(sortedEntities[0].id);
        }
    }, [selectedAgentId, sortedEntities]);

    useEffect(() => {
        if (selectedAgentId) {
            window.history.replaceState(null, '', `${window.location.pathname}${window.location.search}#agent=${selectedAgentId}`);
        }
    }, [selectedAgentId]);

    const selectedEntity = sortedEntities.find((entity) => entity.id === selectedAgentId) || sortedEntities[0] || null;
    const selectedAgent = isAgentEntity(selectedEntity) ? selectedEntity : null;

    const selectedTablesQuery = useQuery({
        queryKey: ['agent-tables', selectedAgent?.id],
        queryFn: () => fetchAgentTables(selectedAgent?.id || ''),
        enabled: !!selectedAgent,
        refetchInterval: 2000
    });

    const tables = selectedTablesQuery.data?.tables || [];
    const latestVersion = latestVersionQuery.data?.version || '';

    function addLog(text: string) {
        setLogs((prev) => [
            {
                id: Date.now() + Math.floor(Math.random() * 1000),
                text,
                ts: new Date().toLocaleTimeString('en-US', { hour12: false })
            },
            ...prev
        ].slice(0, 50));
    }

    async function refreshAll() {
        await Promise.all([
            queryClient.invalidateQueries({ queryKey: ['entities'] }),
            queryClient.invalidateQueries({ queryKey: ['unread-counts'] }),
            queryClient.invalidateQueries({ queryKey: ['mail-staleness'] }),
            queryClient.invalidateQueries({ queryKey: ['alerts-status'] }),
            queryClient.invalidateQueries({ queryKey: ['agent-tables', selectedAgent?.id] })
        ]);
        addLog('manual refresh');
    }

    async function onCreateInvite() {
        try {
            addLog('creating invite');
            const result = await createInvite();
            if (!result.success || !result.username) {
                addLog(`invite failed: ${result.error || 'unknown error'}`);
                return;
            }
            setInviteModal({ open: true, payload: result });
            await queryClient.invalidateQueries({ queryKey: ['entities'] });
            setSelectedAgentId(result.username);
            setDetailOpen(true);
            addLog(`invite created: ${result.username}`);
        } catch (error) {
            addLog(`invite error: ${(error as Error).message}`);
        }
    }

    async function onCopyEmail() {
        if (!selectedAgent || !selectedAgent.id.startsWith('id_')) {
            addLog('email copy requires an agent row');
            return;
        }
        try {
            const data = await fetchAgentEmail(selectedAgent.id);
            if (navigator.clipboard) {
                await navigator.clipboard.writeText(data.email);
            }
            addLog(`email copied: ${data.email}`);
        } catch (error) {
            addLog(`email copy failed: ${(error as Error).message}`);
        }
    }

    async function onResetAgent() {
        if (!selectedAgent || !selectedAgent.id.startsWith('id_')) {
            addLog('reset requires an agent row');
            return;
        }
        const ok = window.confirm(`Reset metrics for ${displayName(selectedAgent)} (${selectedAgent.id})?`);
        if (!ok) {
            return;
        }
        try {
            const result = await resetAgent(selectedAgent.id);
            if (result.success) {
                addLog(`metrics reset: ${selectedAgent.id}`);
                await refreshAll();
            } else {
                addLog(`reset failed: ${result.message || 'unknown'}`);
            }
        } catch (error) {
            addLog(`reset failed: ${(error as Error).message}`);
        }
    }

    async function onDeleteAgent() {
        if (!selectedAgent || !selectedAgent.id.startsWith('id_')) {
            addLog('delete requires an agent row');
            return;
        }
        const ok = window.confirm(`Delete agent ${displayName(selectedAgent)} (${selectedAgent.id})?`);
        if (!ok) {
            return;
        }
        try {
            const result = await deleteAgent(selectedAgent.id);
            if (result.success) {
                addLog(`agent deleted: ${selectedAgent.id}`);
                await refreshAll();
            } else {
                addLog(`delete failed: ${result.message || 'unknown'}`);
            }
        } catch (error) {
            addLog(`delete failed: ${(error as Error).message}`);
        }
    }

    async function onEditDisplayName() {
        if (!selectedEntity) {
            return;
        }
        const currentName = selectedEntity.display_name || '';
        const fallback = selectedEntity.original_hostname || selectedEntity.hostname || selectedEntity.id;
        const next = window.prompt(`Enter display name (leave empty to use "${fallback}")`, currentName);
        if (next === null) {
            return;
        }
        try {
            await updateAgentName(selectedEntity.id, next.trim());
            addLog(`name updated: ${next.trim() || '(cleared)'}`);
            await queryClient.invalidateQueries({ queryKey: ['entities'] });
        } catch (error) {
            addLog(`name update failed: ${(error as Error).message}`);
        }
    }

    async function onReorderAgentRows(agentIds: string[]) {
        try {
            await reorderAgents(agentIds);
            addLog('host order updated');
            await queryClient.invalidateQueries({ queryKey: ['entities'] });
        } catch (error) {
            addLog(`reorder failed: ${(error as Error).message}`);
        }
    }

    useEffect(() => {
        function onKeyDown(event: KeyboardEvent) {
            if (event.key === 'F5' || ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'r')) {
                return;
            }
            const target = event.target as HTMLElement | null;
            if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA')) {
                return;
            }
            const key = event.key.toLowerCase();
            const currentIndex = sortedEntities.findIndex((entity) => entity.id === selectedAgentId);

            if (key === 'arrowdown' || key === 'j') {
                event.preventDefault();
                const nextIndex = Math.min(currentIndex + 1, sortedEntities.length - 1);
                if (sortedEntities[nextIndex]) {
                    setSelectedAgentId(sortedEntities[nextIndex].id);
                    setDetailOpen(true);
                }
                return;
            }
            if (key === 'arrowup' || key === 'k') {
                event.preventDefault();
                const nextIndex = Math.max(currentIndex - 1, 0);
                if (sortedEntities[nextIndex]) {
                    setSelectedAgentId(sortedEntities[nextIndex].id);
                    setDetailOpen(true);
                }
                return;
            }
            if (key === 'enter') {
                event.preventDefault();
                setDetailOpen(true);
                return;
            }
            if (key === 'escape') {
                event.preventDefault();
                setInviteModal({ open: false, payload: null });
                setDetailOpen(false);
                return;
            }
            if (key === 'r') {
                event.preventDefault();
                void refreshAll();
                return;
            }
            if (key === 'i') {
                event.preventDefault();
                void onCreateInvite();
                return;
            }
            if (key === 'm') {
                event.preventDefault();
                void onCopyEmail();
                return;
            }
            if (key === 'x') {
                event.preventDefault();
                void onResetAgent();
                return;
            }
            if (key === 'd') {
                event.preventDefault();
                void onDeleteAgent();
            }
        }

        document.addEventListener('keydown', onKeyDown);
        return () => document.removeEventListener('keydown', onKeyDown);
    }, [selectedAgentId, sortedEntities, selectedAgent, selectedEntity]);

    const alertsStatusText = useMemo(() => {
        const data = alertsQuery.data;
        if (!data) {
            return 'alerts: loading';
        }
        if (!data.configured) {
            return 'alerts: not configured';
        }
        if (data.enabled && data.mode === 'active') {
            return 'alerts: active';
        }
        return 'alerts: webhook dry-run';
    }, [alertsQuery.data]);

    const unreadCounts = unreadQuery.data?.counts || {};
    const totalUnread = Object.values(unreadCounts).reduce((sum, count) => sum + count, 0);
    const staleThresholdLabel = useMemo(() => {
        const hours = Number(stalenessQuery.data?.threshold_hours || 336);
        if (hours % 24 === 0) {
            return `${Math.floor(hours / 24)}D`;
        }
        return `${hours}H`;
    }, [stalenessQuery.data?.threshold_hours]);

    if (entitiesQuery.isLoading) {
        return <div className="full-screen-state">Loading Lumenmon UI...</div>;
    }
    if (entitiesQuery.isError) {
        return <div className="full-screen-state error">Failed to load /api/entities</div>;
    }

    return (
        <main className="layout legacy-layout">
            <div className="main-content">
                <div className="left-column">
                    <LoggerPanel logs={logs} />
                    <AgentsTable
                        entities={sortedEntities}
                        staleMailMap={staleMailMap}
                        selectedAgentId={selectedAgentId}
                        onReorder={onReorderAgentRows}
                        onSelect={(id) => {
                            setSelectedAgentId(id);
                            setDetailOpen(true);
                        }}
                    />
                </div>

                <div className="detail-column">
                    {!detailOpen || !selectedEntity ? (
                        <div id="detail-panel" className="detail-panel-empty">
                            <span className="detail-placeholder">← Select an agent and press Enter</span>
                        </div>
                    ) : (
                        <section id="detail-panel" className="panel detail-panel">
                            <div className="detail-header">
                                <h2>
                                    <span className={`status-dot ${selectedEntity.status || 'offline'}`} />
                                    {displayName(selectedEntity)}
                                    <button type="button" className="edit-name-btn" onClick={() => void onEditDisplayName()} title="Edit display name">✎</button>
                                </h2>
                                <div className="detail-header-right">
                                    <span className="detail-status">{selectedEntity.id}</span>
                                    {selectedEntity.type !== 'invite' ? (
                                        <span className="status-warnings">
                                            {[
                                                selectedEntity.has_mqtt_user === false ? 'MQTT USER MISSING' : null,
                                                selectedEntity.has_table === false ? 'SQL TABLES MISSING' : null,
                                                staleMailMap[selectedEntity.id] ? `MAIL STALE > ${staleThresholdLabel}` : null
                                            ].filter(Boolean).join(' · ')}
                                        </span>
                                    ) : null}
                                </div>
                            </div>

                            {selectedEntity.type === 'invite' ? (
                                <div className="invite-status-info">
                                    <div className="invite-status-title">Invite Status: Active</div>
                                    <div className="invite-status-text">
                                        This invite is waiting for an agent to connect. Use `i` to generate another invite URL.
                                    </div>
                                </div>
                            ) : selectedEntity.mail_only || selectedEntity.is_mail_only ? (
                                <>
                                    <MessagesWidget agentId={selectedEntity.id} onLog={addLog} />
                                    <div className="mail-only-info">This host has no agent installed. It only sends mail via SMTP.</div>
                                </>
                            ) : (
                                <div className="detail-content">
                                    <div id="widgets-container">
                                        <MetricWidgets
                                            tables={tables}
                                            latestVersion={latestVersion}
                                            agentVersion={selectedEntity.agent_version || ''}
                                        />
                                    </div>

                                    <MessagesWidget agentId={selectedEntity.id} onLog={addLog} />

                                    <div id="metrics-section" className="metrics-section">
                                        <AllMetricsTable
                                            agentId={selectedEntity.id}
                                            tables={tables}
                                            latestVersion={latestVersion}
                                            onLog={addLog}
                                        />
                                    </div>
                                </div>
                            )}
                        </section>
                    )}
                </div>
            </div>

            <footer className="shortcut-footer legacy-shortcuts">
                <div className="footer-left">
                    <span>↑/k</span>
                    <span>↓/j</span>
                    <span>select</span>
                    <span>·</span>
                    <span>enter view</span>
                    <span>·</span>
                    <button className="kbd-clickable" onClick={() => void onCreateInvite()} type="button">i invite</button>
                    <span>·</span>
                    <button className="kbd-clickable" onClick={() => void onCopyEmail()} type="button">m email</button>
                    <span>·</span>
                    <button className="kbd-clickable" onClick={() => void refreshAll()} type="button">r refresh</button>
                    <span>·</span>
                    <button className="kbd-clickable" onClick={() => void onResetAgent()} type="button">x reset</button>
                    <span>·</span>
                    <button className="kbd-clickable" onClick={() => void onDeleteAgent()} type="button">d delete</button>
                    <span>·</span>
                    <span>esc close</span>
                </div>
                <div className="footer-right">
                    <span className="status-compact">console: online</span>
                    <span className="status-compact">{alertsStatusText}</span>
                    <span className="status-compact">mail unread: {totalUnread}</span>
                    <a className="status-compact linkish" href="/debug/collectors">debug</a>
                </div>
            </footer>

            {inviteModal.open && inviteModal.payload ? (
                <div className="modal-backdrop" onClick={() => setInviteModal({ open: false, payload: null })}>
                    <div className="modal" onClick={(event) => event.stopPropagation()}>
                        <h3>Invite Created</h3>
                        <p className="empty-copy">Copy this now. It is shown once.</p>
                        <div className="kv-list">
                            <div><span>Username</span><strong>{inviteModal.payload.username}</strong></div>
                            <div><span>Email</span><strong>{inviteModal.payload.email_address}</strong></div>
                        </div>
                        <textarea value={inviteModal.payload.install_command || ''} readOnly rows={4} />
                        <div className="modal-actions">
                            <button
                                type="button"
                                className="pill interactive"
                                onClick={async () => {
                                    const value = inviteModal.payload?.install_command || '';
                                    if (value && navigator.clipboard) {
                                        await navigator.clipboard.writeText(value);
                                        addLog('copied install command');
                                    }
                                }}
                            >
                                Copy Command
                            </button>
                            <button type="button" className="pill interactive" onClick={() => setInviteModal({ open: false, payload: null })}>Close</button>
                        </div>
                    </div>
                </div>
            ) : null}
        </main>
    );
}

import { useEffect, useMemo, useRef, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { deleteMessage, fetchAgentMessages, fetchMessage } from '../api';
import { emailLocalPart, formatMessageTime } from '../lib';
import type { Message } from '../types';

type Props = {
    agentId: string;
    onLog: (entry: string) => void;
};

export function MessagesWidget({ agentId, onLog }: Props) {
    const queryClient = useQueryClient();
    const [selectedId, setSelectedId] = useState<number | null>(null);
    const rowRefs = useRef<Array<HTMLButtonElement | null>>([]);

    const messagesQuery = useQuery({
        queryKey: ['agent-messages', agentId],
        queryFn: () => fetchAgentMessages(agentId),
        refetchInterval: 20000
    });

    const selectedMessageQuery = useQuery({
        queryKey: ['message', selectedId],
        queryFn: () => fetchMessage(selectedId as number),
        enabled: selectedId !== null
    });

    const messages = messagesQuery.data?.messages || [];
    const unreadCount = useMemo(() => messages.filter((message) => !message.read).length, [messages]);

    useEffect(() => {
        setSelectedId(null);
        rowRefs.current = [];
    }, [agentId]);

    useEffect(() => {
        if (selectedId === null) {
            return;
        }
        if (!messages.some((message) => message.id === selectedId)) {
            setSelectedId(null);
        }
    }, [messages, selectedId]);

    function focusRow(index: number) {
        const row = rowRefs.current[index];
        if (!row) {
            return;
        }
        row.focus();
        row.scrollIntoView({ block: 'nearest' });
    }

    function onListKeyDown(event: React.KeyboardEvent<HTMLDivElement>) {
        if (!messages.length) {
            return;
        }

        const key = event.key.toLowerCase();
        const currentIndex = messages.findIndex((message) => message.id === selectedId);

        if (key === 'arrowdown' || key === 'j') {
            event.preventDefault();
            const nextIndex = currentIndex < 0 ? 0 : Math.min(currentIndex + 1, messages.length - 1);
            setSelectedId(messages[nextIndex].id);
            focusRow(nextIndex);
            return;
        }

        if (key === 'arrowup' || key === 'k') {
            event.preventDefault();
            const nextIndex = currentIndex < 0 ? messages.length - 1 : Math.max(currentIndex - 1, 0);
            setSelectedId(messages[nextIndex].id);
            focusRow(nextIndex);
            return;
        }

        if (key === 'home') {
            event.preventDefault();
            setSelectedId(messages[0].id);
            focusRow(0);
            return;
        }

        if (key === 'end') {
            event.preventDefault();
            const nextIndex = messages.length - 1;
            setSelectedId(messages[nextIndex].id);
            focusRow(nextIndex);
            return;
        }

        if (key === 'escape') {
            event.preventDefault();
            setSelectedId(null);
        }
    }

    async function onDelete(message: Message) {
        try {
            await deleteMessage(message.id);
            if (selectedId === message.id) {
                setSelectedId(null);
            }
            await queryClient.invalidateQueries({ queryKey: ['agent-messages', agentId] });
            await queryClient.invalidateQueries({ queryKey: ['unread-counts'] });
            onLog('message deleted');
        } catch (error) {
            onLog(`message delete failed: ${(error as Error).message}`);
        }
    }

    return (
        <section className="widget-grid messages-widget">
            <article className="widget grid-lg">
                <div className="tui-metric-box">
                    <div className="widget-header">
                        <h3>mail</h3>
                        <span className="badge">{unreadCount} unread</span>
                    </div>

                    {messages.length === 0 ? (
                        <p className="mail-empty">No mail for this host.</p>
                    ) : (
                        <div className="mail-list" tabIndex={0} onKeyDown={onListKeyDown} aria-label="Mail messages list">
                            {messages.map((message, index) => {
                                const selected = selectedId === message.id;
                                return (
                                    <button
                                        type="button"
                                        key={message.id}
                                        ref={(node) => {
                                            rowRefs.current[index] = node;
                                        }}
                                        tabIndex={selected ? 0 : -1}
                                        className={`mail-row ${selected ? 'selected' : ''}`}
                                        onClick={() => setSelectedId(selected ? null : message.id)}
                                        onFocus={() => setSelectedId(message.id)}
                                    >
                                        <span className={`mail-dot ${message.read ? 'read' : 'unread'}`} />
                                        <span className="mail-from">{emailLocalPart(message)}</span>
                                        <span className="mail-subject">{message.subject || '(no subject)'}</span>
                                        <span className="mail-time">{formatMessageTime(message.received_at)}</span>
                                    </button>
                                );
                            })}
                        </div>
                    )}

                    {selectedMessageQuery.data ? (
                        <article className="mail-expanded">
                            <header>
                                <strong>{selectedMessageQuery.data.subject || '(no subject)'}</strong>
                                <button
                                    type="button"
                                    className="action-link danger"
                                    onClick={() => onDelete(selectedMessageQuery.data as Message)}
                                >
                                    delete
                                </button>
                            </header>
                            <div className="mail-meta">
                                <span>from {selectedMessageQuery.data.mail_from}</span>
                                <span>{new Date(selectedMessageQuery.data.received_at).toLocaleString()}</span>
                            </div>
                            <pre>{selectedMessageQuery.data.body || '(empty)'}</pre>
                        </article>
                    ) : null}
                </div>
            </article>
        </section>
    );
}

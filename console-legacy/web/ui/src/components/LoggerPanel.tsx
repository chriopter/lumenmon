import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { fetchCollectorCoverage } from '../api';

type LogEntry = {
    id: number;
    text: string;
    ts: string;
};

type Props = {
    logs: LogEntry[];
};

export function LoggerPanel({ logs }: Props) {
    const coverageQuery = useQuery({
        queryKey: ['collector-coverage'],
        queryFn: fetchCollectorCoverage,
        refetchInterval: 30000
    });

    const coverageText = useMemo(() => {
        if (!coverageQuery.data) {
            return 'collectors: loading coverage...';
        }
        const summary = coverageQuery.data.summary;
        const missing = coverageQuery.data.collectors
            .filter((collector) => collector.status === 'no_data')
            .map((collector) => collector.collector)
            .sort();
        const header = `collectors without data: ${summary.metric_collectors_without_data}/${summary.metric_collectors}`;
        if (!missing.length) {
            return `${header} (none)`;
        }
        return `${header} -> ${missing.join(', ')}`;
    }, [coverageQuery.data]);

    return (
        <section className="log-box" id="log-box">
            <div className="logo-ascii">{`  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝`}</div>
            <div className="log-list" id="log-entries">
                {logs.map((log) => (
                    <p key={log.id}>
                        <span>[{log.ts}]</span> {log.text}
                    </p>
                ))}
            </div>
            <div className="collector-coverage">[debug] {coverageText}</div>
        </section>
    );
}

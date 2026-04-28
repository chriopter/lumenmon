import { useEffect, useRef } from 'react';
import * as echarts from 'echarts';
import type { MetricPoint } from '../types';

type Props = {
    title: string;
    points: MetricPoint[];
    thresholds?: { warn?: number | null; crit?: number | null };
    unit: string;
    color: string;
};

export function TimeSeriesChart({ title, points, thresholds, unit, color }: Props) {
    const chartRef = useRef<HTMLDivElement | null>(null);

    useEffect(() => {
        if (!chartRef.current) {
            return;
        }

        const chart = echarts.init(chartRef.current, undefined, { renderer: 'canvas' });
        const warn = thresholds?.warn;
        const crit = thresholds?.crit;

        chart.setOption({
            animation: false,
            grid: { left: 40, right: 16, top: 24, bottom: 24 },
            tooltip: {
                trigger: 'axis',
                backgroundColor: '#0f172a',
                borderColor: '#334155',
                textStyle: { color: '#e2e8f0' },
                formatter: (params: unknown) => {
                    const typed = params as Array<{ value: [number, number] }>;
                    if (!typed[0]) {
                        return 'No data';
                    }
                    const dt = new Date(typed[0].value[0]);
                    return `${dt.toLocaleTimeString()}<br/>${typed[0].value[1].toFixed(1)}${unit}`;
                }
            },
            xAxis: {
                type: 'time',
                axisLabel: { color: '#93a7c1' },
                axisLine: { lineStyle: { color: '#334155' } }
            },
            yAxis: {
                type: 'value',
                axisLabel: {
                    color: '#93a7c1',
                    formatter: (value: number) => `${value}${unit}`
                },
                splitLine: { lineStyle: { color: '#1e293b' } }
            },
            series: [
                {
                    type: 'line',
                    smooth: true,
                    showSymbol: false,
                    lineStyle: { width: 2, color },
                    areaStyle: { color, opacity: 0.08 },
                    markLine: {
                        symbol: 'none',
                        lineStyle: { type: 'dashed', width: 1 },
                        data: [
                            ...(warn !== null && warn !== undefined
                                ? [{ yAxis: warn, lineStyle: { color: '#f59e0b' } }]
                                : []),
                            ...(crit !== null && crit !== undefined
                                ? [{ yAxis: crit, lineStyle: { color: '#ef4444' } }]
                                : [])
                        ]
                    },
                    data: points.map((point) => [point.timestamp * 1000, point.value])
                }
            ]
        });

        const onResize = () => chart.resize();
        window.addEventListener('resize', onResize);
        return () => {
            window.removeEventListener('resize', onResize);
            chart.dispose();
        };
    }, [color, points, thresholds?.crit, thresholds?.warn, unit]);

    return (
        <section className="panel chart-panel">
            <h3>{title}</h3>
            <div ref={chartRef} className="chart-canvas" />
        </section>
    );
}

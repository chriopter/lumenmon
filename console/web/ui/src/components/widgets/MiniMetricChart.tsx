import { useEffect, useRef } from 'react';
import * as echarts from 'echarts';
import type { MetricPoint } from '../../types';

type Props = {
    points: MetricPoint[];
    color: string;
    unit?: string;
    yMin?: number;
    yMax?: number;
};

export function MiniMetricChart({ points, color, unit = '', yMin, yMax }: Props) {
    const ref = useRef<HTMLDivElement | null>(null);
    const latestWindowPoints = points.filter((point) => point.timestamp >= (Date.now() / 1000) - 3600);
    const chartPoints = latestWindowPoints.length > 1 ? latestWindowPoints : points;

    useEffect(() => {
        if (!ref.current) {
            return;
        }
        const chart = echarts.init(ref.current, undefined, { renderer: 'canvas' });
        chart.setOption({
            animation: false,
            grid: { left: 2, right: 2, top: 2, bottom: 2 },
            tooltip: {
                trigger: 'axis',
                borderWidth: 1,
                borderColor: '#3b4265',
                backgroundColor: 'rgba(20,22,35,0.97)',
                textStyle: { color: '#d7e3f4', fontSize: 11 },
                formatter: (params: unknown) => {
                    const typed = params as Array<{ value: [number, number] }>;
                    if (!typed[0]) return 'no data';
                    const dt = new Date(typed[0].value[0]);
                    return `${dt.toLocaleTimeString()}<br/>${typed[0].value[1].toFixed(1)}${unit}`;
                }
            },
            xAxis: { type: 'time', show: false },
            yAxis: { type: 'value', show: false, min: yMin, max: yMax },
            series: [
                {
                    type: 'line',
                    showSymbol: false,
                    smooth: true,
                    lineStyle: { color, width: 1.1 },
                    areaStyle: { color, opacity: 0.08 },
                    data: chartPoints.map((point) => [point.timestamp * 1000, point.value])
                }
            ]
        });

        return () => chart.dispose();
    }, [chartPoints, color, unit, yMax, yMin]);

    return <div className="mini-chart" ref={ref} />;
}

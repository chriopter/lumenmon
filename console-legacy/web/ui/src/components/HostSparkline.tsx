import { useEffect, useRef } from 'react';
import * as echarts from 'echarts';
import type { MetricPoint } from '../types';

type Props = {
    points: MetricPoint[];
    color?: string;
    yMax?: number;
};

export function HostSparkline({ points, color = '#6ea8d6', yMax }: Props) {
    const ref = useRef<HTMLDivElement | null>(null);
    const latestWindowPoints = points.filter((point) => point.timestamp >= (Date.now() / 1000) - 3600);
    const chartPoints = latestWindowPoints.length > 1 ? latestWindowPoints : points;

    useEffect(() => {
        if (!ref.current || chartPoints.length === 0) {
            return;
        }

        const chart = echarts.init(ref.current, undefined, { renderer: 'canvas' });
        chart.setOption({
            animation: false,
            grid: { left: 0, right: 0, top: 0, bottom: 0 },
            xAxis: { type: 'time', show: false },
            yAxis: { type: 'value', show: false, min: 0, max: yMax },
            series: [
                {
                    type: 'line',
                    showSymbol: false,
                    smooth: true,
                    lineStyle: { width: 1.05, color },
                    areaStyle: { color, opacity: 0.06 },
                    data: chartPoints.map((point) => [point.timestamp * 1000, point.value])
                }
            ]
        });

        return () => chart.dispose();
    }, [chartPoints, color, yMax]);

    if (chartPoints.length === 0) {
        return <span className="sparkline-empty">-</span>;
    }

    return <div className="host-sparkline" ref={ref} />;
}

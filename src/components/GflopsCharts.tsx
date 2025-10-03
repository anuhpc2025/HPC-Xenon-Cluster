import React, { useMemo } from "react";
import {
    ResponsiveContainer,
    LineChart,
    Line,
    XAxis,
    YAxis,
    CartesianGrid,
    Tooltip,
} from "recharts";
import type { BenchmarkRun } from "../types";

interface GflopsChartsProps {
    runs: BenchmarkRun[];
}

interface CustomTooltipProps {
    active?: boolean;
    payload?: any[];
    label?: any;
}

// Custom tooltip that only shows the top-most GFLOPS point
const CustomTooltip: React.FC<CustomTooltipProps> = ({
                                                         active,
                                                         payload,
                                                     }) => {
    if (active && payload && payload.length) {
        // get point with maximum gflops
        const top = payload.reduce((prev, curr) => {
            return (prev.value ?? -Infinity) > (curr.value ?? -Infinity) ? prev : curr;
        });

        const record = top.payload;

        return (
            <div className="bg-white border border-gray-300 rounded px-3 py-2 text-sm shadow-md">
                <div>
                    <span className="font-semibold">Run: </span>
                    {record.label}
                </div>
                <div>
                    <span className="font-semibold">N:</span> {record.N}
                </div>
                <div>
                    <span className="font-semibold">NB:</span> {record.NB}
                </div>
                <div>
                    <span className="font-semibold">GFLOPS:</span>{" "}
                    {record.gflops.toFixed(2)}
                </div>
            </div>
        );
    }
    return null;
};

export const GflopsCharts: React.FC<GflopsChartsProps> = ({ runs }) => {
    // Flatten all runs into { N, NB, gflops, label }
    const chartData = useMemo(() => {
        const points: {
            N: number;
            NB: number;
            gflops: number;
            label: string;
        }[] = [];

        runs.forEach((r) => {
            if (r.out?.runs?.length) {
                r.out.runs.forEach((rr) => {
                    if (
                        Number.isFinite(rr?.N) &&
                        Number.isFinite(rr?.NB) &&
                        Number.isFinite(rr?.gflops)
                    ) {
                        points.push({
                            N: rr.N,
                            NB: rr.NB,
                            gflops: rr.gflops,
                            label: `${r.group}/${r.run}${
                                rr.tv !== undefined ? ` [tv:${rr.tv}]` : ""
                            }`,
                        });
                    }
                });
            } else if (r.best) {
                points.push({
                    N: r.best.N,
                    NB: r.best.NB,
                    gflops: r.best.gflops,
                    label: `${r.group}/${r.run}`,
                });
            }
        });

        return points;
    }, [runs]);

    // Compute axis extents with padding
    const nExtent = useMemo(() => {
        const vals = chartData.map((p) => p.N).filter(Number.isFinite);
        if (vals.length === 0) return [0, 1];
        const min = Math.min(...vals);
        const max = Math.max(...vals);
        return [min * 0.98, max * 1.02];
    }, [chartData]);

    const nbExtent = useMemo(() => {
        const vals = chartData.map((p) => p.NB).filter(Number.isFinite);
        if (vals.length === 0) return [0, 1];
        const min = Math.min(...vals);
        const max = Math.max(...vals);
        return [min * 0.95, max * 1.05];
    }, [chartData]);

    const gflopsExtent = useMemo(() => {
        const vals = chartData.map((p) => p.gflops).filter(Number.isFinite);
        if (vals.length === 0) return [0, 1];
        const min = Math.min(...vals);
        const max = Math.max(...vals);
        return [min * 0.95, max * 1.05];
    }, [chartData]);

    return (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* GFLOPS vs N */}
            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
                <h3 className="text-md font-semibold text-gray-800 mb-3">
                    GFLOPS vs N (matrix size)
                </h3>
                <ResponsiveContainer width="100%" height={300}>
                    <LineChart data={[...chartData].sort((a, b) => a.N - b.N)}>
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis type="number" dataKey="N" domain={nExtent} />
                        <YAxis domain={gflopsExtent} />
                        <Tooltip content={<CustomTooltip />} />
                        <Line
                            type="monotone"
                            dataKey="gflops"
                            stroke="#3b82f6"
                            dot={{ r: 3 }}
                            // 🔥 smooth animation back
                            isAnimationActive={true}
                            animationDuration={600}
                            animationEasing="ease-in-out"
                        />
                    </LineChart>
                </ResponsiveContainer>
            </div>

            {/* GFLOPS vs NB */}
            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
                <h3 className="text-md font-semibold text-gray-800 mb-3">
                    GFLOPS vs Block Size (NB)
                </h3>
                <ResponsiveContainer width="100%" height={300}>
                    <LineChart data={[...chartData].sort((a, b) => a.NB - b.NB)}>
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis type="number" dataKey="NB" domain={nbExtent} />
                        <YAxis domain={gflopsExtent} />
                        <Tooltip content={<CustomTooltip />} />
                        <Line
                            type="monotone"
                            dataKey="gflops"
                            stroke="#10b981"
                            dot={{ r: 3 }}
                            // 🔥 smooth animation back
                            isAnimationActive={true}
                            animationDuration={600}
                            animationEasing="ease-in-out"
                        />
                    </LineChart>
                </ResponsiveContainer>
            </div>
        </div>
    );
};
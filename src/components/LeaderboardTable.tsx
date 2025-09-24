import React, { useState } from 'react';
import {
    ChevronUp,
    ChevronDown,
    Trophy,
    Medal,
    Award,
    Eye,
} from 'lucide-react';
import type { BenchmarkRun } from '../types';
import { RunDetailsModal } from './RunDetailsModal';

interface LeaderboardTableProps {
    runs: BenchmarkRun[];
    suite: string;
}

type SortField = 'gflops' | 'group' | 'run' | 'timeSec' | 'testsPassed';
type SortDirection = 'asc' | 'desc';

export const LeaderboardTable: React.FC<LeaderboardTableProps> = ({ runs, suite }) => {
    const [sortField, setSortField] = useState<SortField>('gflops');
    const [sortDirection, setSortDirection] = useState<SortDirection>('desc');
    const [, setSelectedRun] = useState<BenchmarkRun | null>(null);
    const [modalOpen, setModalOpen] = useState(false);
    const [runDetails, setRunDetails] = useState<any>(null);
    const [loadingDetails, setLoadingDetails] = useState(false);
    const [detailsError, setDetailsError] = useState<string | null>(null);

    const [showBestPerGroup, setShowBestPerGroup] = useState(true);

    const handleViewDetails = async (run: BenchmarkRun) => {
        setSelectedRun(run);
        setModalOpen(true);
        setLoadingDetails(true);
        setDetailsError(null);
        setRunDetails(null);

        try {
            const response = await fetch(`${import.meta.env.BASE_URL}data/runs/${run.suite}/${run.group}/${run.run}/run.json`);
            if (!response.ok) {
                throw new Error(`Failed to load run details: ${response.status} ${response.statusText}`);
            }
            const data = await response.json();
            setRunDetails(data);
        } catch (error) {
            setDetailsError(error instanceof Error ? error.message : 'Failed to load run details');
        } finally {
            setLoadingDetails(false);
        }
    };

    const closeModal = () => {
        setModalOpen(false);
        setSelectedRun(null);
        setRunDetails(null);
        setDetailsError(null);
    };

    const handleSort = (field: SortField) => {
        if (sortField === field) {
            setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
        } else {
            setSortField(field);
            setSortDirection(field === 'gflops' ? 'desc' : 'asc');
        }
    };

    // Get best run per group
    const bestPerGroupRuns = Object.values(
        runs.reduce<Record<string, BenchmarkRun>>((acc, run) => {
            if (!acc[run.group] || run.best.gflops > acc[run.group].best.gflops) {
                acc[run.group] = run;
            }
            return acc;
        }, {})
    );

    // decide which runs to display
    const runsToDisplay = showBestPerGroup ? bestPerGroupRuns : runs;

    const sortedRuns = [...runsToDisplay].sort((a, b) => {
        let aValue: string | number;
        let bValue: string | number;

        switch (sortField) {
            case 'gflops':
                aValue = a.best.gflops;
                bValue = b.best.gflops;
                break;
            case 'timeSec':
                aValue = a.best.timeSec;
                bValue = b.best.timeSec;
                break;
            case 'testsPassed':
                aValue = a.outSummary.testsPassed;
                bValue = b.outSummary.testsPassed;
                break;
            case 'group':
                aValue = a.group;
                bValue = b.group;
                break;
            case 'run':
                aValue = a.run;
                bValue = b.run;
                break;
            default:
                aValue = a.best.gflops;
                bValue = b.best.gflops;
        }

        if (typeof aValue === 'string' && typeof bValue === 'string') {
            return sortDirection === 'asc'
                ? aValue.localeCompare(bValue)
                : bValue.localeCompare(aValue);
        }

        return sortDirection === 'asc'
            ? (aValue as number) - (bValue as number)
            : (bValue as number) - (aValue as number);
    });

    const getRankIcon = (index: number) => {
        switch (index) {
            case 0: return <Trophy className="w-5 h-5 text-yellow-500" />;
            case 1: return <Medal className="w-5 h-5 text-gray-400" />;
            case 2: return <Award className="w-5 h-5 text-amber-600" />;
            default: return <span className="w-5 h-5 flex items-center justify-center text-sm font-bold text-gray-500">#{index + 1}</span>;
        }
    };

    const formatGflops = (gflops: number) => {
        if (gflops >= 1000) {
            return `${(gflops / 1000).toFixed(2)}T`;
        }
        return gflops.toFixed(3);
    };

    const getSuccessRate = (summary: BenchmarkRun['outSummary']) => {
        const rate = (summary.testsPassed / summary.testsTotal) * 100;
        return rate;
    };

    const SortIcon = ({ field }: { field: SortField }) => {
        if (sortField !== field) {
            return <div className="w-4 h-4" />;
        }
        return sortDirection === 'asc' ? (
            <ChevronUp className="w-4 h-4" />
        ) : (
            <ChevronDown className="w-4 h-4" />
        );
    };

    return (
        <>
            <div className="bg-white rounded-lg shadow-sm border border-gray-200">
                <div className="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
                    <h2 className="text-lg font-semibold text-gray-900">
                        {suite} Leaderboard ({runsToDisplay.length}{' '}
                        {showBestPerGroup ? 'groups' : 'runs'})
                    </h2>
                    {/* Toggle */}
                    <button
                        onClick={() => setShowBestPerGroup((prev) => !prev)}
                        className="px-3 py-1 bg-blue-100 hover:bg-blue-200 text-blue-700 text-sm font-medium rounded-lg transition-colors"
                    >
                        {showBestPerGroup ? 'Show All Runs' : 'Show Best Per Group'}
                    </button>
                </div>

                <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                        <thead className="bg-gray-50">
                        <tr>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Rank
                            </th>
                            <th
                                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                                onClick={() => handleSort('group')}
                            >
                                <div className="flex items-center space-x-1">
                                    <span>Group</span>
                                    <SortIcon field="group" />
                                </div>
                            </th>
                            <th
                                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                                onClick={() => handleSort('run')}
                            >
                                <div className="flex items-center space-x-1">
                                    <span>Run</span>
                                    <SortIcon field="run" />
                                </div>
                            </th>
                            <th
                                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                                onClick={() => handleSort('gflops')}
                            >
                                <div className="flex items-center space-x-1">
                                    <span>Performance (GFLOPS)</span>
                                    <SortIcon field="gflops" />
                                </div>
                            </th>
                            <th
                                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                                onClick={() => handleSort('timeSec')}
                            >
                                <div className="flex items-center space-x-1">
                                    <span>Time (sec)</span>
                                    <SortIcon field="timeSec" />
                                </div>
                            </th>
                            <th
                                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                                onClick={() => handleSort('testsPassed')}
                            >
                                <div className="flex items-center space-x-1">
                                    <span>Test Results</span>
                                    <SortIcon field="testsPassed" />
                                </div>
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Matrix Size
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Actions
                            </th>
                        </tr>
                        </thead>
                        <tbody className="bg-white divide-y divide-gray-200">
                        {sortedRuns.map((run, index) => (
                            <tr
                                key={run.id}
                                className={`hover:bg-gray-50 ${
                                    index < 3 ? 'bg-gradient-to-r from-blue-50 to-transparent' : ''
                                }`}
                            >
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="flex items-center">{getRankIcon(index)}</div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="text-sm font-medium text-gray-900">
                                        {run.group}
                                    </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="text-sm text-gray-900">{run.run}</div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="text-lg font-bold text-blue-600">
                                        {formatGflops(run.best.gflops)}
                                    </div>
                                    <div className="text-xs text-gray-500">
                                        {run.best.gflops.toLocaleString()} GFLOPS
                                    </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="text-sm text-gray-900">
                                        {run.best.timeSec > 0 ? `${run.best.timeSec}s` : 'N/A'}
                                    </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="flex items-center space-x-2">
                                        <div
                                            className={`px-2 py-1 text-xs font-medium rounded-full ${
                                                getSuccessRate(run.outSummary) === 100
                                                    ? 'bg-green-100 text-green-800'
                                                    : 'bg-yellow-100 text-yellow-800'
                                            }`}
                                        >
                                            {getSuccessRate(run.outSummary).toFixed(0)}%
                                        </div>
                                        <div className="text-xs text-gray-500">
                                            {run.outSummary.testsPassed}/{run.outSummary.testsTotal}
                                        </div>
                                    </div>
                                    {run.hasErr && (
                                        <div className="text-xs text-red-600 mt-1">Has errors</div>
                                    )}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <div className="text-sm text-gray-900">
                                        N={run.best.N.toLocaleString()}
                                    </div>
                                    <div className="text-xs text-gray-500">
                                        NB={run.best.NB}
                                    </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                    <button
                                        onClick={() => handleViewDetails(run)}
                                        className="inline-flex items-center space-x-2 px-3 py-1 bg-blue-100 hover:bg-blue-200 text-blue-700 text-sm font-medium rounded-lg transition-colors"
                                    >
                                        <Eye className="w-4 h-4" />
                                        <span>View Details</span>
                                    </button>
                                </td>
                            </tr>
                        ))}
                        </tbody>
                    </table>
                </div>

                {runsToDisplay.length === 0 && (
                    <div className="text-center py-12">
                        <div className="text-gray-500">No benchmark runs available</div>
                    </div>
                )}
            </div>
            <RunDetailsModal
                isOpen={modalOpen}
                onClose={closeModal}
                runData={runDetails}
                loading={loadingDetails}
                error={detailsError}
            />
        </>
    );
};
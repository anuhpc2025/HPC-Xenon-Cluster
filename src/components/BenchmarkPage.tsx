import { useEffect, useState } from 'react';
import type { BenchmarkData, BenchmarkSuite } from '../types';
import { LeaderboardTable } from './LeaderboardTable';
import { AlertCircle, BarChart3, Clock, CheckCircle } from 'lucide-react';

interface BenchmarkPageProps {
    suite: BenchmarkSuite;
    suiteName: string;
    description: string;
}

export const BenchmarkPage: React.FC<BenchmarkPageProps> = ({
                                                                suite,
                                                                suiteName,
                                                                description,
                                                            }) => {
    const [data, setData] = useState<BenchmarkData | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const fetchData = async () => {
            try {
                setLoading(true);
                const response = await fetch('/data/index.json');
                if (!response.ok) {
                    throw new Error('Failed to fetch data');
                }
                const jsonData: BenchmarkData = await response.json();
                setData(jsonData);
                setError(null);
            } catch (err) {
                setError(err instanceof Error ? err.message : 'An error occurred');
                setData(null);
            } finally {
                setLoading(false);
            }
        };

        fetchData();
    }, []);

    if (loading) {
        return (
            <div className="flex items-center justify-center py-12">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
            </div>
        );
    }

    if (error) {
        return (
            <div className="bg-red-50 border border-red-200 rounded-lg p-6">
                <div className="flex items-center space-x-3">
                    <AlertCircle className="w-6 h-6 text-red-600" />
                    <div>
                        <h3 className="text-lg font-medium text-red-900">
                            Error Loading Data
                        </h3>
                        <p className="text-red-700 mt-1">{error}</p>
                    </div>
                </div>
            </div>
        );
    }

    const filteredRuns = data ? data.runs.filter((r) => r.suite === suite) : [];
    const hasAnyRuns = filteredRuns.length > 0;

    // Split runs by validity
    const errorRuns = filteredRuns.filter((r) => r.hasErr);
    const validPerfRuns = filteredRuns.filter(
        (r) => !r.hasErr && r.best && typeof r.best.gflops === 'number'
    );
    const validSummaryRuns = filteredRuns.filter(
        (r) =>
            !r.hasErr &&
            r.outSummary &&
            typeof r.outSummary.testsTotal === 'number' &&
            typeof r.outSummary.testsPassed === 'number' &&
            (r.outSummary.testsTotal ?? 0) > 0
    );

    // "Coming soon" suites (unchanged behavior: only when no runs at all)
    if (
        !hasAnyRuns &&
        (suite === 'ExascaleClimate' || suite === 'StructuralSimulation')
    ) {
        return (
            <div className="space-y-6">
                <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
                    <div className="mx-auto w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                        <BarChart3 className="w-8 h-8 text-gray-400" />
                    </div>
                    <h2 className="text-xl font-semibold text-gray-900 mb-2">
                        {suiteName}
                    </h2>
                    <p className="text-gray-600 mb-4">{description}</p>
                    <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 max-w-md mx-auto">
                        <p className="text-blue-800 text-sm">
                            This benchmark suite is coming soon. Data collection and analysis
                            tools are currently being developed.
                        </p>
                    </div>
                </div>
            </div>
        );
    }

    // Stats (ignore error runs for performance/success metrics)
    const totalRuns = filteredRuns.length;
    const errorCount = errorRuns.length;

    const avgGflops =
        validPerfRuns.length > 0
            ? validPerfRuns.reduce((sum, r) => sum + (r.best!.gflops || 0), 0) /
            validPerfRuns.length
            : null;

    const maxGflops =
        validPerfRuns.length > 0
            ? Math.max(...validPerfRuns.map((r) => r.best!.gflops))
            : null;

    const { totalPassed, totalTests } = validSummaryRuns.reduce(
        (acc, r) => {
            acc.totalPassed += r.outSummary!.testsPassed ?? 0;
            acc.totalTests += r.outSummary!.testsTotal ?? 0;
            return acc;
        },
        { totalPassed: 0, totalTests: 0 }
    );
    const successRate =
        totalTests > 0 ? (totalPassed / totalTests) * 100 : null;

    const hasValidLeaderboard = validPerfRuns.length > 0;

    return (
        <div className="space-y-6">
            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                <h1 className="text-2xl font-bold text-gray-900 mb-2">{suiteName}</h1>
                <p className="text-gray-600">{description}</p>

                {data && (
                    <div className="mt-4 text-sm text-gray-500">
                        Last updated: {new Date(data.generatedAt).toLocaleString()}
                    </div>
                )}
            </div>

            {hasAnyRuns && (
                <>
                    <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                            <div className="flex items-center space-x-3">
                                <BarChart3 className="w-8 h-8 text-blue-600" />
                                <div>
                                    <div className="text-2xl font-bold text-gray-900">
                                        {totalRuns}
                                    </div>
                                    <div className="text-sm text-gray-600">Total Runs</div>
                                </div>
                            </div>
                        </div>

                        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                            <div className="flex items-center space-x-3">
                                <AlertCircle className="w-8 h-8 text-red-600" />
                                <div>
                                    <div className="text-2xl font-bold text-gray-900">
                                        {errorCount}
                                    </div>
                                    <div className="text-sm text-gray-600">Error Runs</div>
                                </div>
                            </div>
                        </div>

                        {maxGflops !== null && (
                            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                                <div className="flex items-center space-x-3">
                                    <Clock className="w-8 h-8 text-green-600" />
                                    <div>
                                        <div className="text-2xl font-bold text-gray-900">
                                            {maxGflops >= 1000
                                                ? `${(maxGflops / 1000).toFixed(1)}T`
                                                : maxGflops.toFixed(1)}
                                        </div>
                                        <div className="text-sm text-gray-600">Peak GFLOPS</div>
                                    </div>
                                </div>
                            </div>
                        )}

                        {avgGflops !== null && (
                            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                                <div className="flex items-center space-x-3">
                                    <BarChart3 className="w-8 h-8 text-purple-600" />
                                    <div>
                                        <div className="text-2xl font-bold text-gray-900">
                                            {avgGflops >= 1000
                                                ? `${(avgGflops / 1000).toFixed(1)}T`
                                                : avgGflops.toFixed(1)}
                                        </div>
                                        <div className="text-sm text-gray-600">Avg GFLOPS</div>
                                    </div>
                                </div>
                            </div>
                        )}

                        {successRate !== null && (
                            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                                <div className="flex items-center space-x-3">
                                    <CheckCircle className="w-8 h-8 text-emerald-600" />
                                    <div>
                                        <div className="text-2xl font-bold text-gray-900">
                                            {successRate.toFixed(1)}%
                                        </div>
                                        <div className="text-sm text-gray-600">Success Rate</div>
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>

                    {errorCount > 0 && (
                        <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 flex items-start space-x-3">
                            <AlertCircle className="w-5 h-5 text-amber-700 mt-0.5" />
                            <p className="text-amber-800 text-sm">
                                {errorCount} run{errorCount === 1 ? '' : 's'} encountered
                                errors and are excluded from performance and success-rate
                                statistics, as well as the leaderboard.
                            </p>
                        </div>
                    )}
                </>
            )}

            {hasValidLeaderboard ? (
                <LeaderboardTable runs={validPerfRuns} suite={suite} />
            ) : hasAnyRuns ? (
                <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
                    <BarChart3 className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                    <h3 className="text-lg font-medium text-gray-900 mb-2">
                        No Successful Runs Yet
                    </h3>
                    <p className="text-gray-600">
                        We found runs for {suiteName}, but none produced valid performance
                        results.
                    </p>
                    {errorCount > 0 && (
                        <p className="text-gray-500 mt-2">
                            {errorCount} run{errorCount === 1 ? '' : 's'} failed.
                        </p>
                    )}
                </div>
            ) : (
                <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
                    <BarChart3 className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                    <h3 className="text-lg font-medium text-gray-900 mb-2">
                        No Data Available
                    </h3>
                    <p className="text-gray-600">
                        No benchmark runs found for {suiteName}.
                    </p>
                </div>
            )}
        </div>
    );
};
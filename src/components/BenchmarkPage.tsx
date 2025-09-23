import { useEffect, useMemo, useState } from 'react';
import type { BenchmarkData, BenchmarkSuite } from '../types';
import { LeaderboardTable } from './LeaderboardTable';
import {
    AlertCircle,
    BarChart3,
    Clock,
    Search,
    Filter as FilterIcon,
} from 'lucide-react';

interface BenchmarkPageProps {
    suite: BenchmarkSuite;
    suiteName: string;
    description: string;
}

type StatusFilter = 'pass' | 'fail';
// type SortOption =
//     | 'gflops-asc'
//     | 'gflops-desc'
//     | 'time-asc'
//     | 'time-desc'
//     | 'n-asc'
//     | 'n-desc'
//     | 'newest'
//     | 'oldest';

export const BenchmarkPage: React.FC<BenchmarkPageProps> = ({
                                                                suite,
                                                                suiteName,
                                                                description,
                                                            }) => {
    // Data and lifecycle
    const [data, setData] = useState<BenchmarkData | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    // Filters and controls
    const [searchQuery, setSearchQuery] = useState('');
    const [statusFilter, setStatusFilter] = useState<StatusFilter>('pass');

    // Sort options (no toggle, explicit options only)
    // const [sortOption, setSortOption] = useState<SortOption>('gflops-desc');

    // Range inputs (empty = no bound)
    const [nMinInput, setNMinInput] = useState<string>('');
    const [nMaxInput, setNMaxInput] = useState<string>('');
    const [gMinInput, setGMinInput] = useState<string>('');
    const [gMaxInput, setGMaxInput] = useState<string>('');

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

    // Accessors (defensive against varying shapes)
    const getGflops = (r: any): number => {
        const v =
            r?.best?.gflops ??
            r?.gflops ??
            r?.metrics?.gflops ??
            r?.out?.gflops ??
            r?.result?.gflops ??
            Number.NaN;
        return typeof v === 'number' ? v : Number(v);
    };

    // const getTime = (r: any): number => {
    //     const v =
    //         r?.best?.timeMs ??
    //         r?.best?.time_ms ??
    //         r?.best?.timeMsAvg ??
    //         r?.best?.time ??
    //         r?.timeMs ??
    //         r?.elapsedMs ??
    //         r?.durationMs ??
    //         Number.NaN;
    //     return typeof v === 'number' ? v : Number(v);
    // };

    const getN = (r: any): number => {
        // Probe common locations for problem size "N"
        const v =
            r?.best?.n ??
            r?.best?.N ??
            r?.n ??
            r?.N ??
            r?.params?.n ??
            r?.params?.N ??
            r?.input?.n ??
            r?.input?.N ??
            r?.problem?.n ??
            r?.problem?.N ??
            r?.size ??
            Number.NaN;
        return typeof v === 'number' ? v : Number(v);
    };

    const getTimestamp = (r: any): number => {
        const raw =
            r?.startedAt ??
            r?.timestamp ??
            r?.date ??
            r?.endedAt ??
            r?.createdAt ??
            null;
        if (raw == null) return 0;
        if (typeof raw === 'number') return raw;
        const t = Date.parse(String(raw));
        return Number.isNaN(t) ? 0 : t;
    };

    // Base filtering by suite
    const filteredRuns = useMemo(() => {
        return data ? data.runs.filter((r: any) => r.suite === suite) : [];
    }, [data, suite]);

    const hasAnyRuns = filteredRuns.length > 0;

    // Split runs by validity
    const errorRuns = useMemo(
        () => filteredRuns.filter((r: any) => r.hasErr),
        [filteredRuns]
    );

    const validPerfRuns = useMemo(
        () =>
            filteredRuns.filter((r: any) => {
                if (r.hasErr) return false;
                const g = getGflops(r);
                return Number.isFinite(g);
            }),
        [filteredRuns]
    );

    // Stats (ignore error runs for performance metrics)
    const totalRuns = filteredRuns.length;
    const errorCount = errorRuns.length;

    const avgGflops =
        validPerfRuns.length > 0
            ? validPerfRuns.reduce((sum, r) => sum + (getGflops(r) || 0), 0) /
            validPerfRuns.length
            : null;

    const maxGflops =
        validPerfRuns.length > 0
            ? Math.max(...validPerfRuns.map((r) => getGflops(r)))
            : null;

    const hasValidLeaderboard = validPerfRuns.length > 0;

    // Dataset the filters operate on (pass or fail)
    const datasetBase = statusFilter === 'pass' ? validPerfRuns : errorRuns;

    // Extents for placeholders
    const nExtent = useMemo(() => {
        const vals = datasetBase
            .map((r) => getN(r))
            .filter((v) => Number.isFinite(v));
        if (vals.length === 0)
            return null as null | { min: number; max: number };
        return { min: Math.min(...vals), max: Math.max(...vals) };
    }, [datasetBase]);

    const gExtent = useMemo(() => {
        const vals = (statusFilter === 'pass' ? datasetBase : [])
            .map((r) => getGflops(r))
            .filter((v) => Number.isFinite(v));
        if (vals.length === 0)
            return null as null | { min: number; max: number };
        return { min: Math.min(...vals), max: Math.max(...vals) };
    }, [datasetBase, statusFilter]);

    // Effective numeric bounds (empty input => undefined, i.e., no bound)
    const nMin = nMinInput.trim() === '' ? undefined : Number(nMinInput);
    const nMax = nMaxInput.trim() === '' ? undefined : Number(nMaxInput);
    const gMin = gMinInput.trim() === '' ? undefined : Number(gMinInput);
    const gMax = gMaxInput.trim() === '' ? undefined : Number(gMaxInput);

    // Filter + sort pipeline
    const visibleRuns = useMemo(() => {
        const q = searchQuery.trim().toLowerCase();

        const filtered = datasetBase.filter((r) => {
            // Text match
            if (q) {
                try {
                    if (!JSON.stringify(r).toLowerCase().includes(q)) return false;
                } catch {
                    return false;
                }
            }

            // N range
            const n = getN(r);
            if (nMin !== undefined) {
                if (!Number.isFinite(n) || n < nMin) return false;
            }
            if (nMax !== undefined) {
                if (!Number.isFinite(n) || n > nMax) return false;
            }

            // GFLOPS range (only applies to pass set)
            if (statusFilter === 'pass') {
                const g = getGflops(r);
                if (gMin !== undefined) {
                    if (!Number.isFinite(g) || g < gMin) return false;
                }
                if (gMax !== undefined) {
                    if (!Number.isFinite(g) || g > gMax) return false;
                }
            }

            return true;
        });

        // const valueFor = (r: any): number => {
        //     switch (sortOption) {
        //         case 'gflops-asc':
        //         case 'gflops-desc':
        //             return getGflops(r);
        //         case 'time-asc':
        //         case 'time-desc':
        //             return getTime(r);
        //         case 'n-asc':
        //         case 'n-desc':
        //             return getN(r);
        //         case 'newest':
        //         case 'oldest':
        //         default:
        //             return getTimestamp(r);
        //     }
        // };

        // const isAsc =
        //     sortOption.endsWith('-asc') || sortOption === 'oldest';

        // const isDate = sortOption === 'newest' || sortOption === 'oldest';

        // const cmp = (a: any, b: any) => {
        //     const av = valueFor(a);
        //     const bv = valueFor(b);
        //
        //     // Treat NaN as bottom
        //     const aNaN = !Number.isFinite(av);
        //     const bNaN = !Number.isFinite(bv);
        //     if (aNaN && bNaN) return 0;
        //     if (aNaN) return 1;
        //     if (bNaN) return -1;
        //
        //     if (av < bv) return isAsc ? -1 : 1;
        //     if (av > bv) return isAsc ? 1 : -1;
        //
        //     // Secondary tiebreak: newest first
        //     const at = getTimestamp(a);
        //     const bt = getTimestamp(b);
        //     if (at < bt) return 1;
        //     if (at > bt) return -1;
        //     return 0;
        // };

        // Edge: when sorting newest/oldest, timestamps are the primary key
        // if (isDate) {
        //     return filtered
        //         .slice()
        //         .sort((a, b) => (isAsc ? 1 : -1) * (getTimestamp(a) - getTimestamp(b)));
        // }

        // Otherwise, use comparator above
        return filtered.slice().sort();
        // return filtered.slice().sort(cmp);
    }, [datasetBase, searchQuery, statusFilter, nMin, nMax, gMin, gMax]);
    // }, [datasetBase, searchQuery, statusFilter, nMin, nMax, gMin, gMax, sortOption]);

    // const clearFilters = () => {
    //     setSearchQuery('');
    //     setStatusFilter('pass');
    //     setSortOption('gflops-desc');
    //     setNMinInput('');
    //     setNMaxInput('');
    //     setGMinInput('');
    //     setGMaxInput('');
    // };

    // Early returns after hooks (to keep hook order stable)
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

    // "Coming soon" suites (only when no runs at all)
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
                            This benchmark suite is coming soon. Data collection and
                            analysis tools are currently being developed.
                        </p>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="space-y-6">
            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                <h1 className="text-2xl font-bold text-gray-900 mb-2">
                    {suiteName}
                </h1>
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

                    {/* Filters */}
                    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4 md:p-6">
                        <div className="flex items-center gap-2 mb-4">
                            <FilterIcon className="w-4 h-4 text-gray-700" />
                            <h3 className="text-sm font-semibold text-gray-800">
                                Filters
                            </h3>
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-12 gap-4">
                            {/* Search */}
                            <div className="md:col-span-5">
                                <label
                                    htmlFor="run-search"
                                    className="block text-sm font-medium text-gray-700 mb-1"
                                >
                                    Search
                                </label>
                                <div className="relative">
                                    <Search className="w-5 h-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
                                    <input
                                        id="run-search"
                                        type="text"
                                        value={searchQuery}
                                        onChange={(e) => setSearchQuery(e.target.value)}
                                        placeholder="Model, device, notes, ..."
                                        className="w-full rounded-md border border-gray-300 pl-10 pr-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                    />
                                </div>
                            </div>

                            {/* Status (compact) */}
                            <div className="md:col-span-1">
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    Status
                                </label>
                                <select
                                    value={statusFilter}
                                    onChange={(e) => setStatusFilter(e.target.value as StatusFilter)}
                                    className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                >
                                    <option value="pass">Pass</option>
                                    <option value="fail">Fail</option>
                                </select>
                            </div>

                            {/*/!* Sort (single select with explicit options) *!/*/}
                            {/*<div className="md:col-span-3">*/}
                            {/*    <label className="block text-sm font-medium text-gray-700 mb-1">*/}
                            {/*        Sort*/}
                            {/*    </label>*/}
                            {/*    <select*/}
                            {/*        value={sortOption}*/}
                            {/*        onChange={(e) => setSortOption(e.target.value as SortOption)}*/}
                            {/*        className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"*/}
                            {/*    >*/}
                            {/*        <option value="gflops-asc">GFLOPS (asc)</option>*/}
                            {/*        <option value="gflops-desc">GFLOPS (desc)</option>*/}
                            {/*        <option value="time-asc">Time (asc)</option>*/}
                            {/*        <option value="time-desc">Time (desc)</option>*/}
                            {/*        <option value="n-asc">N (asc)</option>*/}
                            {/*        <option value="n-desc">N (desc)</option>*/}
                            {/*        <option value="newest">Newest</option>*/}
                            {/*        <option value="oldest">Oldest</option>*/}
                            {/*    </select>*/}
                            {/*</div>*/}

                            {/*/!* Reset *!/*/}
                            {/*<div className="md:col-span-2 flex items-end">*/}
                            {/*    <button*/}
                            {/*        type="button"*/}
                            {/*        onClick={clearFilters}*/}
                            {/*        className="w-full md:w-auto px-3 py-2 rounded-md text-sm border border-gray-300 bg-white hover:bg-gray-50 text-gray-700"*/}
                            {/*    >*/}
                            {/*        Reset filters*/}
                            {/*    </button>*/}
                            {/*</div>*/}

                            {/* N range */}
                            <div className="md:col-span-1">
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    N min
                                </label>
                                <input
                                    type="number"
                                    inputMode="numeric"
                                    step="1"
                                    value={nMinInput}
                                    onChange={(e) => setNMinInput(e.target.value)}
                                    placeholder={nExtent ? String(Math.floor(nExtent.min)) : ''}
                                    className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                />
                            </div>
                            <div className="md:col-span-2">
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    N max
                                </label>
                                <input
                                    type="number"
                                    inputMode="numeric"
                                    step="1"
                                    value={nMaxInput}
                                    onChange={(e) => setNMaxInput(e.target.value)}
                                    placeholder={nExtent ? String(Math.ceil(nExtent.max)) : ''}
                                    className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                />
                            </div>

                            {/* GFLOPS range (pass only) */}
                            <div className="md:col-span-1">
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    GFLOPS min
                                </label>
                                <input
                                    type="number"
                                    inputMode="decimal"
                                    value={gMinInput}
                                    onChange={(e) => setGMinInput(e.target.value)}
                                    placeholder={gExtent ? String(Math.floor(gExtent.min)) : ''}
                                    disabled={statusFilter === 'fail'}
                                    className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                                        statusFilter === 'fail'
                                            ? 'bg-gray-100 text-gray-400 border-gray-200'
                                            : 'border-gray-300'
                                    }`}
                                />
                            </div>
                            <div className="md:col-span-2">
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    GFLOPS max
                                </label>
                                <input
                                    type="number"
                                    inputMode="decimal"
                                    value={gMaxInput}
                                    onChange={(e) => setGMaxInput(e.target.value)}
                                    placeholder={gExtent ? String(Math.ceil(gExtent.max)) : ''}
                                    disabled={statusFilter === 'fail'}
                                    className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                                        statusFilter === 'fail'
                                            ? 'bg-gray-100 text-gray-400 border-gray-200'
                                            : 'border-gray-300'
                                    }`}
                                />
                            </div>

                            {/* Count */}
                            <div className="md:col-span-12">
                                <div className="text-sm text-gray-600">
                                    Showing {visibleRuns.length} of {datasetBase.length}{' '}
                                    {statusFilter === 'pass' ? 'successful' : 'failed'} run
                                    {datasetBase.length === 1 ? '' : 's'}
                                </div>
                            </div>
                        </div>
                    </div>
                </>
            )}

            {/* Results */}
            {statusFilter === 'pass' ? (
                    hasValidLeaderboard ? (
                        visibleRuns.length > 0 ? (
                            <LeaderboardTable runs={visibleRuns as any[]} suite={suite} />
                        ) : (
                            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
                                <Search className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                                <h3 className="text-lg font-medium text-gray-900 mb-2">
                                    No matching results
                                </h3>
                                <p className="text-gray-600">
                                    Try adjusting your filters or search term.
                                </p>
                            </div>
                        )
                    ) : hasAnyRuns ? (
                        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
                            <BarChart3 className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                            <h3 className="text-lg font-medium text-gray-900 mb-2">
                                No Successful Runs Yet
                            </h3>
                            <p className="text-gray-600">
                                We found runs for {suiteName}, but none produced valid
                                performance results.
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
                    )
                ) : // Fail status view
                errorRuns.length > 0 ? (
                    visibleRuns.length > 0 ? (
                        <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
                            <div className="px-6 py-4 border-b border-gray-200">
                                <h3 className="text-lg font-medium text-gray-900">
                                    Failed Runs
                                </h3>
                            </div>
                            <div className="divide-y divide-gray-200">
                                {visibleRuns.map((r: any, idx: number) => {
                                    const ts = getTimestamp(r);
                                    const when = ts > 0 ? new Date(ts).toLocaleString() : '-';
                                    const label =
                                        r?.model ??
                                        r?.name ??
                                        r?.id ??
                                        r?.device ??
                                        `Run #${idx + 1}`;
                                    const errMsg =
                                        r?.errorMessage ??
                                        r?.errMessage ??
                                        r?.err ??
                                        r?.outErr ??
                                        r?.failure ??
                                        'Unknown error';
                                    return (
                                        <div
                                            key={r?.id ?? r?.runId ?? r?.name ?? idx}
                                            className="px-6 py-4 flex items-start gap-3"
                                        >
                                            <AlertCircle className="w-5 h-5 text-red-600 mt-0.5 shrink-0" />
                                            <div className="min-w-0">
                                                <div className="flex items-center justify-between">
                                                    <div className="font-medium text-gray-900 truncate">
                                                        {label}
                                                    </div>
                                                    <div className="text-xs text-gray-500 ml-3 shrink-0">
                                                        {when}
                                                    </div>
                                                </div>
                                                <div className="text-sm text-gray-700 mt-1 break-words">
                                                    {typeof errMsg === 'string' ? (
                                                        errMsg
                                                    ) : (
                                                        <code className="text-xs">
                                                            {(() => {
                                                                try {
                                                                    return JSON.stringify(errMsg);
                                                                } catch {
                                                                    return 'Unknown error';
                                                                }
                                                            })()}
                                                        </code>
                                                    )}
                                                </div>
                                            </div>
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
                    ) : (
                        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
                            <Search className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                            <h3 className="text-lg font-medium text-gray-900 mb-2">
                                No matching failed runs
                            </h3>
                            <p className="text-gray-600">
                                Try adjusting your filters or search term.
                            </p>
                        </div>
                    )
                ) : (
                    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
                        <BarChart3 className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                        <h3 className="text-lg font-medium text-gray-900 mb-2">
                            No Failed Runs
                        </h3>
                        <p className="text-gray-600">
                            No failed runs found for {suiteName}.
                        </p>
                    </div>
                )}
        </div>
    );
};
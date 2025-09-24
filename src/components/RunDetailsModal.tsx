import {useState} from 'react';
import {Clock, Cpu, Database, FileText, Play, Settings, X, Zap, Copy} from 'lucide-react';

interface RunDetailsData {
    id: string;
    suite: string;
    group: string;
    run: string;
    dat?: {
        raw: string;
        parsed: any;
        path: string;
    };
    job?: {
        filename: string;
        raw: string;
        sbatch: any;
        path: string;
    };
    out?: {
        path: string;
        runs: any[];
        summary: {
            testsTotal: number;
            testsPassed: number;
            testsFailed: number;
            testsSkipped: number;
        };
        deviceInfo?: any;
        memInfo?: any;
        traces?: string[];
        startTime?: string;
        endTime?: string;
        residual?: number;
        residualPassed?: boolean;
    };
    err?: any;
    best: {
        gflops: number;
        N: number;
        NB: number;
        timeSec: number;
    };
}

interface RunDetailsModalProps {
    isOpen: boolean;
    onClose: () => void;
    runData: RunDetailsData | null;
    loading: boolean;
    error: string | null;
}

export const RunDetailsModal: React.FC<RunDetailsModalProps> = ({
                                                                    isOpen,
                                                                    onClose,
                                                                    runData,
                                                                    loading,
                                                                    error
                                                                }) => {
    const [copied, setCopied] = useState(false);

    const handleCopy = async () => {
        if (runData?.job?.raw) {
            await navigator.clipboard.writeText(runData.job.raw);
            setCopied(true);
            setTimeout(() => setCopied(false), 2000);
        }
    };

    if (!isOpen) return null;

    const formatGflops = (gflops: number) => {
        if (gflops >= 1000) {
            return `${(gflops / 1000).toFixed(2)}T`;
        }
        return gflops.toFixed(3);
    };

    const formatDuration = (start?: string, end?: string) => {
        if (!start || !end) return 'N/A';
        const startTime = new Date(start);
        const endTime = new Date(end);
        const duration = (endTime.getTime() - startTime.getTime()) / 1000;
        return `${duration.toFixed(1)}s`;
    };

    return (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" style={{margin:0}}>
            <div className="bg-white rounded-lg shadow-xl max-w-6xl w-full max-h-[90vh] overflow-hidden">
                <div className="flex items-center justify-between p-6 border-b border-gray-200">
                    <div className="flex items-center space-x-3">
                        <div className="bg-blue-100 p-2 rounded-lg">
                            <Database className="w-6 h-6 text-blue-600"/>
                        </div>
                        <div>
                            <h2 className="text-xl font-bold text-gray-900">Run Details</h2>
                            {runData && (
                                <p className="text-sm text-gray-600">
                                    {runData.group} / {runData.run}
                                </p>
                            )}
                        </div>
                    </div>
                    <button
                        onClick={onClose}
                        className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
                    >
                        <X className="w-5 h-5 text-gray-500"/>
                    </button>
                </div>

                <div className="overflow-y-auto max-h-[calc(90vh-80px)]">
                    {loading && (
                        <div className="flex items-center justify-center py-12">
                            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
                        </div>
                    )}

                    {error && (
                        <div className="p-6">
                            <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                                <div className="flex items-center space-x-2">
                                    <X className="w-5 h-5 text-red-600"/>
                                    <span className="text-red-800 font-medium">Error loading run details</span>
                                </div>
                                <p className="text-red-700 mt-1 text-sm">{error}</p>
                            </div>
                        </div>
                    )}

                    {runData && !loading && !error && (
                        <div className="p-6 space-y-6">
                            {/* Overview */}
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                                <div className="bg-blue-50 rounded-lg p-4">
                                    <div className="flex items-center space-x-2 mb-2">
                                        <Zap className="w-5 h-5 text-blue-600"/>
                                        <span className="font-medium text-blue-900">Performance</span>
                                    </div>
                                    <div className="text-2xl font-bold text-blue-600">
                                        {formatGflops(runData.best.gflops)}
                                    </div>
                                    <div className="text-sm text-blue-700">
                                        {runData.best.gflops.toLocaleString()} GFLOPS
                                    </div>
                                </div>

                                <div className="bg-green-50 rounded-lg p-4">
                                    <div className="flex items-center space-x-2 mb-2">
                                        <Clock className="w-5 h-5 text-green-600"/>
                                        <span className="font-medium text-green-900">Execution Time</span>
                                    </div>
                                    <div className="text-2xl font-bold text-green-600">
                                        {runData.best.timeSec > 0 ? `${runData.best.timeSec}s` : 'N/A'}
                                    </div>
                                    <div className="text-sm text-green-700">
                                        Duration: {formatDuration(runData.out?.startTime, runData.out?.endTime)}
                                    </div>
                                </div>

                                <div className="bg-purple-50 rounded-lg p-4">
                                    <div className="flex items-center space-x-2 mb-2">
                                        <Cpu className="w-5 h-5 text-purple-600"/>
                                        <span className="font-medium text-purple-900">Matrix Size</span>
                                    </div>
                                    <div className="text-2xl font-bold text-purple-600">
                                        N={runData.best.N.toLocaleString()}
                                    </div>
                                    <div className="text-sm text-purple-700">
                                        Block size: {runData.best.NB}
                                    </div>
                                </div>
                            </div>

                            {/* Test Results */}
                            {runData.out && (
                                <div className="bg-gray-50 rounded-lg p-4">
                                    <h3 className="font-semibold text-gray-900 mb-3 flex items-center space-x-2">
                                        <Play className="w-5 h-5"/>
                                        <span>Test Results</span>
                                    </h3>
                                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                                        <div>
                                            <div className="text-sm text-gray-600">Total Tests</div>
                                            <div
                                                className="text-lg font-semibold">{runData.out.summary.testsTotal}</div>
                                        </div>
                                        <div>
                                            <div className="text-sm text-gray-600">Passed</div>
                                            <div
                                                className="text-lg font-semibold text-green-600">{runData.out.summary.testsPassed}</div>
                                        </div>
                                        <div>
                                            <div className="text-sm text-gray-600">Failed</div>
                                            <div
                                                className="text-lg font-semibold text-red-600">{runData.out.summary.testsFailed}</div>
                                        </div>
                                        <div>
                                            <div className="text-sm text-gray-600">Skipped</div>
                                            <div
                                                className="text-lg font-semibold text-yellow-600">{runData.out.summary.testsSkipped}</div>
                                        </div>
                                    </div>

                                    {runData.out.residual !== undefined && (
                                        <div className="mt-4 pt-4 border-t border-gray-200">
                                            <div className="flex items-center justify-between">
                                                <span className="text-sm text-gray-600">Residual Check</span>
                                                <div className="flex items-center space-x-2">
                                                    <span
                                                        className="text-sm font-mono">{runData.out.residual.toExponential(3)}</span>
                                                    <span className={`px-2 py-1 text-xs font-medium rounded-full ${
                                                        runData.out.residualPassed
                                                            ? 'bg-green-100 text-green-800'
                                                            : 'bg-red-100 text-red-800'
                                                    }`}>
                                                        {runData.out.residualPassed ? 'PASSED' : 'FAILED'}
                                                    </span>
                                                </div>
                                            </div>
                                        </div>
                                    )}
                                </div>
                            )}

                            {/* Device Info (for GPU runs) */}
                            {runData.out?.deviceInfo && (
                                <div className="bg-gray-50 rounded-lg p-4">
                                    <h3 className="font-semibold text-gray-900 mb-3 flex items-center space-x-2">
                                        <Cpu className="w-5 h-5"/>
                                        <span>Device Information</span>
                                    </h3>
                                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                                        <div>
                                            <div className="text-sm text-gray-600">Peak Clock</div>
                                            <div
                                                className="text-lg font-semibold">{runData.out.deviceInfo.peakClockMHz} MHz
                                            </div>
                                        </div>
                                        <div>
                                            <div className="text-sm text-gray-600">SM Version</div>
                                            <div
                                                className="text-lg font-semibold">{runData.out.deviceInfo.smVersion}</div>
                                        </div>
                                        <div>
                                            <div className="text-sm text-gray-600">Number of SMs</div>
                                            <div className="text-lg font-semibold">{runData.out.deviceInfo.numSms}</div>
                                        </div>
                                    </div>
                                </div>
                            )}

                            {/* Memory Info (for GPU runs) */}
                            {runData.out?.memInfo && (
                                <div className="bg-gray-50 rounded-lg p-4">
                                    <h3 className="font-semibold text-gray-900 mb-3 flex items-center space-x-2">
                                        <Database className="w-5 h-5"/>
                                        <span>Memory Usage</span>
                                    </h3>
                                    {runData.out.memInfo.DEVICE && (
                                        <div className="space-y-3">
                                            <h4 className="font-medium text-gray-800">Device Memory</h4>
                                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                                <div>
                                                    <div className="text-sm text-gray-600">HPL Buffers</div>
                                                    <div className="text-lg font-semibold">
                                                        {runData.out.memInfo.DEVICE['HPL buffers']?.avgGiB?.toFixed(2)} GiB
                                                    </div>
                                                </div>
                                                <div>
                                                    <div className="text-sm text-gray-600">Total Used</div>
                                                    <div className="text-lg font-semibold">
                                                        {runData.out.memInfo.DEVICE.Used?.avgGiB?.toFixed(2)} / {runData.out.memInfo.DEVICE.Total?.avgGiB} GiB
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    )}
                                </div>
                            )}

                            {/* Configuration */}
                            {runData.dat && (
                                <div className="bg-gray-50 rounded-lg p-4">
                                    <h3 className="font-semibold text-gray-900 mb-3 flex items-center space-x-2">
                                        <Settings className="w-5 h-5"/>
                                        <span>Configuration</span>
                                    </h3>
                                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                                        {runData.dat.parsed.Ps && (
                                            <div>
                                                <div className="text-gray-600">Process Grid (P)</div>
                                                <div className="font-semibold">{runData.dat.parsed.Ps.join(', ')}</div>
                                            </div>
                                        )}
                                        {runData.dat.parsed.Qs && (
                                            <div>
                                                <div className="text-gray-600">Process Grid (Q)</div>
                                                <div className="font-semibold">{runData.dat.parsed.Qs.join(', ')}</div>
                                            </div>
                                        )}
                                        {runData.dat.parsed.threshold && (
                                            <div>
                                                <div className="text-gray-600">Threshold</div>
                                                <div className="font-semibold">{runData.dat.parsed.threshold}</div>
                                            </div>
                                        )}
                                        {runData.dat.parsed.equilibration !== undefined && (
                                            <div>
                                                <div className="text-gray-600">Equilibration</div>
                                                <div
                                                    className="font-semibold">{runData.dat.parsed.equilibration ? 'Yes' : 'No'}</div>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            )}

                            {/* Job Script */}
                            {runData.job && (
                                <div className="bg-gray-50 rounded-lg p-4">
                                    <h3 className="font-semibold text-gray-900 mb-3 flex items-center space-x-2">
                                        <FileText className="w-5 h-5" />
                                        <span>Job Script ({runData.job.filename})</span>
                                    </h3>

                                    {/* Script area with copy button + feedback inside */}
                                    <div className="bg-gray-900 rounded-lg p-4 overflow-x-auto relative">
                                        {/* Copy button inside code box */}
                                        <button
                                            onClick={handleCopy}
                                            className="absolute top-2 right-2 p-2 rounded-md bg-gray-800 hover:bg-gray-700 transition"
                                            title="Copy script"
                                        >
                                            <Copy className="w-4 h-4 text-gray-300" />
                                        </button>

                                        {/* ✅ Copied feedback sits next to button now */}
                                        {copied && (
                                            <span className="absolute top-3 right-12 text-xs text-green-400">
                Copied!
              </span>
                                        )}

                                        <pre className="text-sm text-gray-100 whitespace-pre-wrap">
              {runData.job.raw}
            </pre>
                                    </div>
                                </div>
                            )}

                            {/* HPL File */}
                            {runData.dat && (
                                <div className="bg-gray-50 rounded-lg p-4">
                                    <h3 className="font-semibold text-gray-900 mb-3 flex items-center space-x-2">
                                        <FileText className="w-5 h-5" />
                                        <span>HPL File (HPL.dat)</span>
                                    </h3>

                                    {/* Code area with copy button */}
                                    <div className="bg-gray-900 rounded-lg p-4 overflow-x-auto relative">
                                        {/* Copy button top-right */}
                                        <button
                                            onClick={handleCopy}
                                            className="absolute top-2 right-2 p-2 rounded-md bg-gray-800 hover:bg-gray-700 transition"
                                            title="Copy script"
                                        >
                                            <Copy className="w-4 h-4 text-gray-300" />
                                        </button>

                                        {/* Copied feedback */}
                                        {copied && (
                                            <span className="absolute top-3 right-12 text-xs text-green-400">
                Copied!
              </span>
                                        )}

                                        <pre className="text-sm text-gray-100 whitespace-pre-wrap">
              {runData.dat.raw}
            </pre>
                                    </div>
                                </div>
                            )}

                            {/* Detailed Run Results */}
                            {runData.out?.runs && runData.out.runs.length > 0 && (
                                <div className="bg-gray-50 rounded-lg p-4">
                                    <h3 className="font-semibold text-gray-900 mb-3 flex items-center space-x-2">
                                        <Database className="w-5 h-5"/>
                                        <span>Detailed Results ({runData.out.runs.length} runs)</span>
                                    </h3>
                                    <div className="overflow-x-auto">
                                        <table className="min-w-full divide-y divide-gray-200">
                                            <thead className="bg-gray-100">
                                            <tr>
                                                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Test
                                                    Variant
                                                </th>
                                                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">N</th>
                                                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">NB</th>
                                                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Time
                                                    (s)
                                                </th>
                                                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">GFLOPS</th>
                                                {runData.suite === 'HPL_NVIDIA' && (
                                                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">GFLOPS/GPU</th>
                                                )}
                                            </tr>
                                            </thead>
                                            <tbody className="bg-white divide-y divide-gray-200">
                                            {runData.out.runs.slice(0, 10).map((run, index) => (
                                                <tr key={index} className="hover:bg-gray-50">
                                                    <td className="px-4 py-2 text-sm font-mono text-gray-900">{run.tv}</td>
                                                    <td className="px-4 py-2 text-sm text-gray-900">{run.N?.toLocaleString()}</td>
                                                    <td className="px-4 py-2 text-sm text-gray-900">{run.NB}</td>
                                                    <td className="px-4 py-2 text-sm text-gray-900">{run.timeSec}</td>
                                                    <td className="px-4 py-2 text-sm font-semibold text-blue-600">
                                                        {formatGflops(run.gflops)}
                                                    </td>
                                                    {runData.suite === 'HPL_NVIDIA' && run.gflopsPerGpu && (
                                                        <td className="px-4 py-2 text-sm text-gray-900">{run.gflopsPerGpu.toLocaleString()}</td>
                                                    )}
                                                </tr>
                                            ))}
                                            </tbody>
                                        </table>
                                        {runData.out.runs.length > 10 && (
                                            <div className="text-center py-2 text-sm text-gray-500">
                                                Showing first 10 of {runData.out.runs.length} runs
                                            </div>
                                        )}
                                    </div>
                                </div>
                            )}

                            {/* Traces (for GPU runs) */}
                            {runData.out?.traces && runData.out.traces.length > 0 && (
                                <div className="bg-gray-50 rounded-lg p-4">
                                    <h3 className="font-semibold text-gray-900 mb-3 flex items-center space-x-2">
                                        <FileText className="w-5 h-5"/>
                                        <span>Execution Traces</span>
                                    </h3>
                                    <div className="space-y-2">
                                        {runData.out.traces.map((trace, index) => (
                                            <div key={index} className="bg-gray-900 rounded p-2">
                                                <code className="text-sm text-gray-100">{trace}</code>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};
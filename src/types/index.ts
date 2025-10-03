export interface BenchmarkRun {
    id: string;
    suite: string;
    group: string;
    run: string;
    best: {
        gflops: number;
        N: number;
        NB: number;
        timeSec: number;
    } | null; // some runs don’t have best
    outSummary: {
        testsTotal: number | null;
        testsPassed: number | null;
        testsFailed: number | null;
        testsSkipped: number | null;
    } | null;
    hasErr: boolean;

    // 🔑 Add this, optional for detailed results
    out?: {
        runs: {
            tv?: string;
            N: number;
            NB: number;
            timeSec: number;
            gflops: number;
            gflopsPerGpu?: number;
        }[];
        summary?: any;
        deviceInfo?: any;
        memInfo?: any;
        traces?: string[];
        startTime?: string;
        endTime?: string;
    };
}

export interface BenchmarkData {
  generatedAt: string;
  runs: BenchmarkRun[];
}

export type BenchmarkSuite = 'HPL' | 'HPL_NVIDIA' | 'ExascaleClimate' | 'StructuralSimulation';

export interface SuiteInfo {
  id: BenchmarkSuite;
  name: string;
  description: string;
  type: 'CPU' | 'GPU' | 'Climate' | 'Structural';
}
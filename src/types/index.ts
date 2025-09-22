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
  };
  outSummary: {
    testsTotal: number;
    testsPassed: number;
    testsFailed: number;
    testsSkipped: number;
  };
  hasErr: boolean;
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
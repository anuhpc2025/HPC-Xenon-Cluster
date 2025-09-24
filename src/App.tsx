import { Routes, Route, Navigate, useParams } from 'react-router';
import { Navigation } from './components/Navigation';
import { BenchmarkPage } from './components/BenchmarkPage';
import type { BenchmarkSuite } from './types';

const suiteDetails = {
    HPL: {
        name: 'HPL (CPU)',
        description: 'High Performance Linpack benchmark measuring CPU floating-point performance using dense linear algebra operations.',
        background:"bg-red-50",
    },
    HPL_NVIDIA: {
        name: 'HPL NVIDIA (GPU)',
        description: 'GPU-accelerated High Performance Linpack benchmark leveraging NVIDIA CUDA cores for maximum computational throughput.',
        background:"bg-green-50",
    },
    ExascaleClimate: {
        name: 'Exascale Climate Emulator',
        description: 'Advanced climate modeling and simulation benchmark designed for exascale computing environments.',
        background:"bg-blue-50",
    },
    StructuralSimulation: {
        name: 'Structural Simulation Toolkit',
        description: 'Comprehensive structural analysis and finite element simulation performance benchmark suite.',
        background:"bg-yellow-50",
    }
};

function SuiteWrapper() {
    const { suiteId } = useParams<{ suiteId: BenchmarkSuite }>();
    const suite = suiteId && suiteDetails[suiteId];

    if (!suite) {
        return <Navigate to="/HPL" replace />;
    }

    return (
        <div className={`min-h-screen ${suite.background}`}>
            <Navigation activeSuite={suiteId!} />
            <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
                <BenchmarkPage
                    suite={suiteId!}
                    suiteName={suite.name}
                    description={suite.description}
                />
            </main>

            <footer className="bg-white border-t border-gray-200 mt-12">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
                    <div className="text-center text-sm text-gray-500">
                        HPC Xenon Cluster Website
                    </div>
                </div>
            </footer>
        </div>
    );
}

function App() {
    return (
        <Routes>
            {/* Default route */}
            <Route path="/" element={<Navigate to="/HPL" replace />} />
            {/* Dynamic suite route */}
            <Route path="/:suiteId" element={<SuiteWrapper />} />
        </Routes>
    );
}

export default App;
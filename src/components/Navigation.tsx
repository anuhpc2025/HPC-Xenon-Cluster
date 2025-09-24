import React from 'react';
import { Cpu, Zap, Cloud, Building } from 'lucide-react';
import { Link } from 'react-router';
import type { BenchmarkSuite, SuiteInfo } from '../types';

interface NavigationProps {
    activeSuite: BenchmarkSuite;
}

const suiteInfos: SuiteInfo[] = [
    {
        id: 'HPL',
        name: 'HPL (CPU)',
        description: 'High Performance Linpack - CPU Performance',
        type: 'CPU',
    },
    {
        id: 'HPL_NVIDIA',
        name: 'HPL NVIDIA (GPU)',
        description: 'High Performance Linpack - GPU Accelerated',
        type: 'GPU',
    },
    {
        id: 'ExascaleClimate',
        name: 'Exascale Climate Emulator',
        description: 'Climate Modeling Performance',
        type: 'Climate',
    },
    {
        id: 'StructuralSimulation',
        name: 'Structural Simulation Toolkit',
        description: 'Structural Analysis Performance',
        type: 'Structural',
    },
];

const getIcon = (type: string) => {
    switch (type) {
        case 'CPU':
            return <Cpu className="w-5 h-5" />;
        case 'GPU':
            return <Zap className="w-5 h-5" />;
        case 'Climate':
            return <Cloud className="w-5 h-5" />;
        case 'Structural':
            return <Building className="w-5 h-5" />;
        default:
            return <Cpu className="w-5 h-5" />;
    }
};

export const Navigation: React.FC<NavigationProps> = ({ activeSuite }) => {
    return (
        <nav className="bg-white border-b border-gray-200">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                {/* Header */}
                <div className="flex justify-between items-center py-4">
                    <div className="flex items-center space-x-3">
                        <div className="bg-blue-600 p-2 rounded-lg">
                            <Zap className="w-6 h-6 text-white" />
                        </div>
                        <div>
                            <h1 className="text-xl font-bold text-gray-900">
                                HPC Xenon Cluster Leaderboard Website
                            </h1>
                            <p className="text-sm text-gray-600">
                                https://github.com/anuhpc2025/HPC-Xenon-Cluster
                            </p>
                        </div>
                    </div>
                </div>

                {/* Suite Navigation */}
                <div className="flex space-x-1 overflow-x-auto pb-4">
                    {suiteInfos.map((suite) => (
                        <Link
                            key={suite.id}
                            to={`/${suite.id}`}
                            className={`flex items-center space-x-2 px-4 py-2 rounded-lg font-medium text-sm whitespace-nowrap transition-colors ${
                                activeSuite === suite.id
                                    ? 'bg-blue-100 text-blue-700 border-2 border-blue-300'
                                    : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100 border-2 border-transparent'
                            }`}
                        >
                            {getIcon(suite.type)}
                            <span>{suite.name}</span>
                        </Link>
                    ))}
                </div>
            </div>
        </nav>
    );
};
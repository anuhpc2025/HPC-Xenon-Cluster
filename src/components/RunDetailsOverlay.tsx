import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { RunDetailsModal } from './RunDetailsModal';

export function RunDetailsOverlay() {
    const { suiteId, group, "*": runPath } = useParams();
    const navigate = useNavigate();

    const [loading, setLoading] = useState(true);
    const [runData, setRunData] = useState<any>(null);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        if (!suiteId || !group || !runPath) return;

        const fetchRun = async () => {
            setLoading(true);
            try {
                const res = await fetch(
                    `${import.meta.env.BASE_URL}data/runs/${suiteId}/${group}/${runPath}/run.json`
                );
                if (!res.ok) throw new Error(`HTTP ${res.status}`);
                setRunData(await res.json());
            } catch (err) {
                setError(err instanceof Error ? err.message : 'Error loading run');
            } finally {
                setLoading(false);
            }
        };

        fetchRun();
    }, [suiteId, group, runPath]);

    const handleClose = () => {
        // go back to suite root
        if (suiteId) navigate(`/${suiteId}`);
    };

    return (
        <RunDetailsModal
            isOpen={true}
            onClose={handleClose}
            runData={runData}
            loading={loading}
            error={error}
        />
    );
}
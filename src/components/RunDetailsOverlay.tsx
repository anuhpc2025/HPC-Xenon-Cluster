import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { RunDetailsModal } from './RunDetailsModal';

export function RunDetailsOverlay() {
    const { suiteId, group, runId } = useParams();
    const navigate = useNavigate();

    const [loading, setLoading] = useState(true);
    const [runData, setRunData] = useState<any>(null);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        if (!suiteId || !group || !runId) return;

        const fetchRun = async () => {
            setLoading(true);
            try {
                const res = await fetch(
                    `${import.meta.env.BASE_URL}data/runs/${suiteId}/${group}/${runId}/run.json`
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
    }, [suiteId, group, runId]);

    const handleClose = () => {
        // go back to suite root
        navigate(`/${suiteId}`);
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
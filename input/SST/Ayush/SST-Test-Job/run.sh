#!/bin/bash
#SBATCH -J sst-halo_batchjobs
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -w node1
#SBATCH --cpus-per-task=16
#SBATCH -t 00:40:00
#SBATCH -o /home/hpc/logs/%x-%A_%a.out
#SBATCH --array=0-14%4    # Changed from 0-15 to 0-14 for 15 total jobs or
# to any other range as needed


set -euo pipefail


APPPY="/home/hpc/Programs/sst-scc-practice/network/scc-network.py"
OUT="/home/hpc/uprof-out/${SLURM_JOB_NAME}_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
mkdir -p "$OUT"


# ----- parameter lists (renamed to avoid GROUPS conflict) -----
declare -a G_LIST=(8 8 8 12 12 12 16 16 16 20 20 20 24 24 24) 
declare -a J_LIST=(4 4 4 4 4 4 4 4 4 8 8 8 8 8 8)            
declare -a K_LIST=(10 20 30 10 20 30 10 20 30 10 20 30 10 20 30)


# Array index: default to 0 if not set (so the script can be tested),
IDX=${SLURM_ARRAY_TASK_ID:-0}


# Debug output to verify array job is running
echo "SLURM_ARRAY_JOB_ID: ${SLURM_ARRAY_JOB_ID:-not set}"
echo "SLURM_ARRAY_TASK_ID: ${SLURM_ARRAY_TASK_ID:-not set}"
echo "SLURM_JOB_ID: ${SLURM_JOB_ID:-not set}"


if (( IDX < 0 || IDX >= ${#G_LIST[@]} )); then
  echo "Error: SLURM_ARRAY_TASK_ID=$IDX is out of range (0..$(( ${#G_LIST[@]} - 1 )))"
  exit 1
fi


g=${G_LIST[$IDX]}
j=${J_LIST[$IDX]}
k=${K_LIST[$IDX]}


echo "[cfg] idx=$IDX groups=$g jobs=$j iters=$k threads=$SLURM_CPUS_PER_TASK" | tee "$OUT/run.log"


unset PMI_RANK PMI_SIZE PMI_FD PMIX_RANK PMIX_NAMESPACE PMIX_SERVER_URI2


/opt/AMDuProf_Linux_x64_5.1.701/bin/AMDuProfCLI collect \
  --config hotspots \
  --profiling-signal 50 \
  -o "$OUT/uprof" \
  sst --num-threads "$SLURM_CPUS_PER_TASK" "$APPPY" -- \
  --app halo --groups "$g" --jobs "$j" --iters "$k" \
  --link_bw 25GB/s --router_latency 150ns --link_latency 100ns \
  | tee -a "$OUT/run.log"


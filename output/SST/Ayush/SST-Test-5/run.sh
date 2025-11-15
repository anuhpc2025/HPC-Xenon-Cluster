#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --ntasks=1                      # One SST process
#SBATCH --cpus-per-task=4               # Matches --num-threads 4
#SBATCH --time=12:00:00                 # Time limit hh:mm:ss
#SBATCH --nodes=1
#SBATCH --nodelist=node1
#SBATCH --output=/home/hpc/logs/%x-%j.out

# No -e so we still run cleanup even if sst exits non-zero
set -uo pipefail

########################################
# 1. Basic environment
########################################

# If you need modules, uncomment these:
# module load sst-core sst-elements

ulimit -l unlimited
ulimit -n 65536

########################################
# 2. Paths & work dir
########################################

SST_WORKDIR=/home/hpc/Programs/sst-scc-practice/network
cd "${SST_WORKDIR}"

SST_PY=./scc-network.py

# Where to store per-run logs
OUT_BASE=/home/hpc/sst-runs
OUT_DIR="${OUT_BASE}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}"
mkdir -p "${OUT_DIR}"
LOG_FILE="${OUT_DIR}/sst.log"

########################################
# 3. Simulation parameters
#    (hardcoded tiny workload so env can't override)
########################################

APP="halo"
GROUPS=1
JOBS=1
ITERS=1

LINK_BW="25GB/s"
ROUTER_LAT="100ns"
LINK_LAT="50ns"

# Threads per rank – default to cpus-per-task from Slurm
SST_THREADS="${SLURM_CPUS_PER_TASK}"

########################################
# 4. Run SST (no MPI, no profiling extras)
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} threads=${SST_THREADS} \
app=${APP} groups=${GROUPS} jobs=${JOBS} iters=${ITERS} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT}" \
  | tee "${LOG_FILE}"

# Run SST and capture all output into LOG_FILE
sst \
  --num-threads="${SST_THREADS}" \
  "${SST_PY}" -- \
    --app "${APP}" \
    --groups "${GROUPS}" \
    --jobs "${JOBS}" \
    --iters "${ITERS}" \
    --link_bw "${LINK_BW}" \
    --router_latency="${ROUTER_LAT}" \
    --link_latency="${LINK_LAT}" \
  >> "${LOG_FILE}" 2>&1

RET=$?

echo "SST_RUN_COMPLETE job=${SLURM_JOB_ID} exit_code=${RET}" \
  | tee -a "${LOG_FILE}"

########################################
# 5. Dump log to Slurm stdout (for GitHub)
########################################

echo "SST_LOG_BEGIN job=${SLURM_JOB_ID}"
cat "${LOG_FILE}"
echo "SST_LOG_END job=${SLURM_JOB_ID}"

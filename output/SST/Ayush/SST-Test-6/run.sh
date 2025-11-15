#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --ntasks=1                      # One SST process
#SBATCH --cpus-per-task=4               # Matches --num-threads 4
#SBATCH --time=00:05:00                 # Time limit hh:mm:ss
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
# 3. Tiny simulation parameters (hard-coded)
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

# Max wall time we allow SST itself (seconds)
TIMEOUT_SEC="${TIMEOUT_SEC:-60}"

########################################
# 4. Signal handler so cancellations are logged
########################################

on_term() {
  local sig="$1"
  echo "$(date -Ins) SST_JOB_TERMINATED signal=${sig}" >> "${LOG_FILE}"
  echo "SST_JOB_TERMINATED signal=${sig}"  # also to stdout
  exit 128
}

trap 'on_term SIGINT' INT
trap 'on_term SIGTERM' TERM

########################################
# 5. Run SST with timeout, log everything
########################################

{
  echo "SST_RUN_START job=${SLURM_JOB_ID} host=$(hostname) threads=${SST_THREADS} \
app=${APP} groups=${GROUPS} jobs=${JOBS} iters=${ITERS} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT} \
timeout_sec=${TIMEOUT_SEC}"
  echo "SST_WORKDIR ${SST_WORKDIR}"
  echo "SST_CMD sst --num-threads=${SST_THREADS} ${SST_PY} -- \\
    --app ${APP} --groups ${GROUPS} --jobs ${JOBS} --iters ${ITERS} \\
    --link_bw ${LINK_BW} --router_latency ${ROUTER_LAT} --link_latency ${LINK_LAT}"
} | tee "${LOG_FILE}"

# Run SST with a hard timeout; capture stdout+stderr to LOG_FILE
/usr/bin/timeout "${TIMEOUT_SEC}" sst \
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

# timeout returns 124 if it kills the command
if [[ "${RET}" -eq 124 ]]; then
  echo "$(date -Ins) SST_RUN_TIMEOUT seconds=${TIMEOUT_SEC}" | tee -a "${LOG_FILE}"
fi

echo "SST_RUN_COMPLETE job=${SLURM_JOB_ID} exit_code=${RET}" | tee -a "${LOG_FILE}"

########################################
# 6. Dump log to Slurm stdout (for GitHub)
########################################

echo "SST_LOG_BEGIN job=${SLURM_JOB_ID}"
cat "${LOG_FILE}"
echo "SST_LOG_END job=${SLURM_JOB_ID}"

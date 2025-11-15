#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --ntasks=1                      # One SST process
#SBATCH --cpus-per-task=4               # SST threads (matches manual command)
#SBATCH --time=00:05:00                 # Time limit hh:mm:ss
#SBATCH --nodes=1
#SBATCH --nodelist=node1
#SBATCH --output=/home/hpc/logs/%x-%j.out

# NO -e so we still print logs even if sst exits non-zero
set -uo pipefail

########################################
# 1. Basic environment
########################################

# If you need modules for SST, uncomment:
# module load sst-core sst-elements

ulimit -l unlimited
ulimit -n 65536

########################################
# 2. Paths & work dir
########################################

SST_WORKDIR=/home/hpc/Programs/sst-scc-practice/network
cd "${SST_WORKDIR}"

APPPY=./scc-network.py

# Per-run log directory + file
OUT_BASE=/home/hpc/sst-runs
OUT_DIR="${OUT_BASE}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}"
mkdir -p "${OUT_DIR}"
LOG_FILE="${OUT_DIR}/sst.log"

########################################
# 3. Workload parameters (env-overridable, safe defaults)
########################################
# You can override these via:
#   sbatch --export=ALL,GROUPS=1000,JOBS=4,ITERS=10 run_sst.sh

app="${APP:-halo}"
g="${GROUPS:-5}"          # default groups
j="${JOBS:-2}"            # default jobs
k="${ITERS:-2}"           # default iters (small but non-trivial)

LINK_BW="${LINK_BW:-25GB/s}"
ROUTER_LAT="${ROUTER_LAT:-100ns}"
LINK_LAT="${LINK_LAT:-50ns}"

threads="${SLURM_CPUS_PER_TASK}"

########################################
# 4. Run SST and tee output (logs survive cancellation)
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} host=$(hostname) threads=${threads} \
app=${app} groups=${g} jobs=${j} iters=${k} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT}" \
  | tee "${LOG_FILE}"

# Run SST, stream output to both Slurm stdout and LOG_FILE
sst \
  --num-threads="${threads}" \
  "${APPPY}" -- \
    --app "${app}" \
    --groups "${g}" \
    --jobs "${j}" \
    --iters "${k}" \
    --link_bw "${LINK_BW}" \
    --router_latency="${ROUTER_LAT}" \
    --link_latency="${LINK_LAT}" \
  2>&1 | tee -a "${LOG_FILE}"

# Capture sst's exit code from the pipeline
RET=${PIPESTATUS[0]}

echo "SST_RUN_COMPLETE job=${SLURM_JOB_ID} exit_code=${RET}" | tee -a "${LOG_FILE}"

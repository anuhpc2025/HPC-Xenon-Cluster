#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --ntasks=1                      # One SST process
#SBATCH --cpus-per-task=4               # SST threads per rank (matches --num-threads 4)
#SBATCH --time=12:00:00                 # Time limit hh:mm:ss
#SBATCH --nodes=1                       # Number of nodes
#SBATCH --nodelist=node1
#SBATCH --output=/home/hpc/logs/%x-%j.out

set -euo pipefail

########################################
# 1. Basic environment
########################################

# If you use modules for MPI/SST, load them here:
# module load openmpi
# module load sst-core sst-elements

ulimit -l unlimited
ulimit -n 65536

########################################
# 2. Paths & work dir
########################################

# Directory that contains scc-network.py
SST_WORKDIR=/home/hpc/Programs/sst-scc-practice/network
cd "${SST_WORKDIR}"

# Your Ember/Merlin network Python config (as you run it manually)
SST_PY=./scc-network.py

# Base directory where we store per-run outputs (for GitHub Actions to pick up)
OUT_BASE=/home/hpc/sst-runs
OUT_DIR="${OUT_BASE}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}"
mkdir -p "${OUT_DIR}"

########################################
# 3. Simulation parameters (env-overridable)
########################################

APP="${APP:-halo}"
GROUPS="${GROUPS:-5}"          # match your working example
JOBS="${JOBS:-2}"              # match your working example
ITERS="${ITERS:-10}"

LINK_BW="${LINK_BW:-25GB/s}"
ROUTER_LAT="${ROUTER_LAT:-100ns}"
LINK_LAT="${LINK_LAT:-50ns}"

PARTITIONER="${PARTITIONER:-linear}"

# Threads per rank – default to cpus-per-task from Slurm
SST_THREADS="${SST_THREADS:-${SLURM_CPUS_PER_TASK}}"

########################################
# 4. SST profiling + timing
########################################
# Use default profiling at these points: clock handlers, event handlers, sync.

PROFILE_POINTS="${PROFILE_POINTS:-clock;event;sync}"

PROFILE_OUT="${OUT_DIR}/sst-profile.txt"
TIMING_JSON="${OUT_DIR}/timing.json"

########################################
# 5. Run info header (for CI)
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} \
ranks=${SLURM_NTASKS} threads_per_rank=${SST_THREADS} \
app=${APP} groups=${GROUPS} jobs=${JOBS} iters=${ITERS} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT} \
partitioner=${PARTITIONER}"
echo "SST_OUTPUT_DIR ${OUT_DIR}"

########################################
# 6. Launch SST (no MPI, just threads)
########################################
# This is the Slurm-ised version of:
#   sst --num-threads 4 ./scc-network.py -- ... (your working command)

sst \
  --num-threads="${SST_THREADS}" \
  --partitioner="${PARTITIONER}" \
  --print-timing-info=3 \
  --timing-info-json="${TIMING_JSON}" \
  --enable-profiling="${PROFILE_POINTS}" \
  --profiling-output="${PROFILE_OUT}" \
  "${SST_PY}" -- \
    --app "${APP}" \
    --groups "${GROUPS}" \
    --jobs "${JOBS}" \
    --iters "${ITERS}" \
    --link_bw "${LINK_BW}" \
    --router_latency "${ROUTER_LAT}" \
    --link_latency "${LINK_LAT}"

RET=$?

########################################
# 7. Dump timing & profile into stdout
########################################

echo "SST_TIMING_JSON_PATH ${TIMING_JSON}"
if [ -f "${TIMING_JSON}" ]; then
  echo "SST_TIMING_JSON_BEGIN"
  # pretty-print if Python JSON module is available; else raw
  python -m json.tool "${TIMING_JSON}" 2>/dev/null || cat "${TIMING_JSON}"
  echo "SST_TIMING_JSON_END"
else
  echo "SST_TIMING_JSON_MISSING ${TIMING_JSON}"
fi

echo "SST_PROFILE_PATH ${PROFILE_OUT}"
if [ -f "${PROFILE_OUT}" ]; then
  echo "SST_PROFILE_BEGIN"
  cat "${PROFILE_OUT}"
  echo "SST_PROFILE_END"
else
  echo "SST_PROFILE_MISSING ${PROFILE_OUT}"
fi

########################################
# 8. Footer for CI parsing
########################################

echo "SST_RUN_COMPLETE job=${SLURM_JOB_ID} \
exit_code=${RET} \
timing_json=${TIMING_JSON} profile=${PROFILE_OUT} \
ranks=${SLURM_NTASKS} threads_per_rank=${SST_THREADS}"

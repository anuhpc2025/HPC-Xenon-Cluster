#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --ntasks=1                      # One SST process
#SBATCH --cpus-per-task=4               # Matches --num-threads 4
#SBATCH --time=12:00:00                 # Time limit hh:mm:ss
#SBATCH --nodes=1
#SBATCH --nodelist=node1
#SBATCH --output=/home/hpc/logs/%x-%j.out

set -euo pipefail

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

########################################
# 3. Simulation parameters (env-overridable)
########################################

APP="${APP:-halo}"
GROUPS="${GROUPS:-2}"
JOBS="${JOBS:-1}"
ITERS="${ITERS:-2}"

LINK_BW="${LINK_BW:-25GB/s}"
ROUTER_LAT="${ROUTER_LAT:-100ns}"
LINK_LAT="${LINK_LAT:-50ns}"

# Threads per rank – default to cpus-per-task from Slurm
SST_THREADS="${SST_THREADS:-${SLURM_CPUS_PER_TASK}}"

########################################
# 4. Run SST (no MPI, no profiling extras)
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} threads=${SST_THREADS} \
app=${APP} groups=${GROUPS} jobs=${JOBS} iters=${ITERS} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT}"

sst \
  --num-threads="${SST_THREADS}" \
  "${SST_PY}" -- \
    --app "${APP}" \
    --groups "${GROUPS}" \
    --jobs "${JOBS}" \
    --iters "${ITERS}" \
    --link_bw "${LINK_BW}" \
    --router_latency "${ROUTER_LAT}" \
    --link_latency "${LINK_LAT}"

RET=$?

echo "SST_RUN_COMPLETE job=${SLURM_JOB_ID} exit_code=${RET}"

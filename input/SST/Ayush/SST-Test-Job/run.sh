#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --ntasks=16                     # Total MPI tasks (1 per node)
#SBATCH --ntasks-per-node=16            # MPI tasks per node
#SBATCH --cpus-per-task=1               # SST threads per MPI rank (EPYC 7313 has 16 cores)
#SBATCH --time=12:00:00                 # Time limit hh:mm:ss
#SBATCH --nodes=1                       # Number of nodes
#SBATCH --nodelist=node1


########################################
# 1. MPI / basic environment
########################################

# If you use modules for MPI/SST, load them here:
# module load openmpi
# module load sst-core sst-elements

# Optional: pick up your PATH/custom env
# source ~/.bashrc

# Ulimits (nice to keep for MPI-heavy sims)
ulimit -l unlimited
ulimit -n 65536

########################################
# 2. SST / model paths
########################################

# Your Ember/Merlin network Python config
SST_PY=/home/hpc/Programs/sst-scc-practice/network/scc-network.py

# Base directory where we store per-run outputs (for GitHub Actions to pick up)
OUT_BASE=/home/hpc/sst-runs
OUT_DIR="${OUT_BASE}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}"
mkdir -p "${OUT_DIR}"

########################################
# 3. Simulation parameters (env-overridable)
#    Override via:
#    sbatch --export=ALL,GROUPS=16,JOBS=8 run_sst_halo.sh
########################################

APP="${APP:-halo}"          # Ember motif
GROUPS="${GROUPS:-8}"
JOBS="${JOBS:-4}"
ITERS="${ITERS:-10}"

LINK_BW="${LINK_BW:-25GB/s}"
ROUTER_LAT="${ROUTER_LAT:-150ns}"
LINK_LAT="${LINK_LAT:-100ns}"

PARTITIONER="${PARTITIONER:-linear}"   # SST partitioner

# Threads per rank – default to cpus-per-task from Slurm
SST_THREADS="${SST_THREADS:-${SLURM_CPUS_PER_TASK}}"

########################################
# 4. Internal SST profiling points (clock / event / sync)
########################################
# Used with:
#   --enable-profiling="${PROFILE_POINTS}"
#   --profiling-output="${PROFILE_OUT}"

PROFILE_POINTS="\
clk_time:sst.profile.handler.clock.time.steady(level=component)[clock];\
evt_time:sst.profile.handler.event.time.steady(level=type,track_ports=true,profile_receives=true)[event];\
sync_time:sst.profile.sync.time.steady[sync]"

PROFILE_OUT="${OUT_DIR}/sst-profile.txt"
TIMING_JSON="${OUT_DIR}/timing.json"

########################################
# 5. Run info header (easy for GitHub Actions to parse)
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} \
ranks=${SLURM_NTASKS} threads_per_rank=${SST_THREADS} \
app=${APP} groups=${GROUPS} jobs=${JOBS} iters=${ITERS} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT} \
partitioner=${PARTITIONER}"
echo "SST_OUTPUT_DIR ${OUT_DIR}"

########################################
# 6. Launch SST under MPI
########################################
# Slurm gives us the allocation (4 nodes × 1 rank per node).
# mpirun will honour that by default.

mpirun \
  sst \
    --partitioner="${PARTITIONER}" \
    --num-threads="${SST_THREADS}" \
    --print-timing-info=2 \
    --timing-info-json="${TIMING_JSON}" \
    --enable-profiling="${PROFILE_POINTS}" \
    --profiling-output="${PROFILE_OUT}" \
    "${SST_PY}" -- \
      --app "${APP}" \
      --groups "${GROUPS}" \
      --jobs "${JOBS}" \
      --iters "${ITERS}" \
      --link_bw "${LINK_BW}" \
      --router_latency="${ROUTER_LAT}" \
      --link_latency="${LINK_LAT}"

########################################
# 7. Footer for CI parsing
########################################

echo "SST_RUN_COMPLETE job=${SLURM_JOB_ID} \
timing_json=${TIMING_JSON} profile=${PROFILE_OUT} \
ranks=${SLURM_NTASKS} threads_per_rank=${SST_THREADS}"

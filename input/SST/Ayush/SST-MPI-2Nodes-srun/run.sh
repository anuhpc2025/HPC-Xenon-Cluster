#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --nodes=2                       # Use 2 nodes
#SBATCH --ntasks-per-node=1            # 1 MPI rank per node  (total ranks = 2)
#SBATCH --cpus-per-task=16             # 16 threads per rank (use all cores per node)
#SBATCH --time=01:00:00                # Time limit hh:mm:ss
#SBATCH --nodelist=node1,node2         # Explicit node list
#SBATCH --output=/home/hpc/logs/%x-%j.out


########################################
# 1. Basic environment
########################################

# Make sure each rank can lock memory & open enough files
ulimit -l unlimited
ulimit -n 65536

# If SST / MPI needs modules, load them here so they propagate to all ranks:
# module load sst mpi/whatever


########################################
# 2. Paths & work dir
#    NOTE: These paths must exist on *all* nodes in SLURM_JOB_NODELIST
########################################

SST_WORKDIR=/home/hpc/Programs/sst-scc-practice/network
cd "${SST_WORKDIR}"

# The SST Python config that builds the Ember/Merlin network.
# Swap to a different topology/app config script if needed.
APPPY=./scc-network.py

# Per-run log directory + file (on shared /home)
OUT_BASE=/home/hpc/sst-runs
OUT_DIR="${OUT_BASE}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}"
mkdir -p "${OUT_DIR}"
LOG_FILE="${OUT_DIR}/sst.log"


########################################
# 3. Parameters for application:
#    These are the main "knobs" you will tune for experiments.
########################################

app="halo"

g=5                 # groups: increase to scale up the number of groups / traffic “clusters”
j=2                 # jobs: number of jobs per group
k=2                 # iterations: number of halo exchanges (higher k => longer simulation)

LINK_BW="25GB/s"    # Link bandwidth
ROUTER_LAT="100ns"  # Router latency
LINK_LAT="50ns"     # Link latency

# Parallelism knobs:
threads="${SLURM_CPUS_PER_TASK}"   # threads per MPI rank (here: 16)
ranks="${SLURM_NTASKS}"           # total MPI ranks (here: 2, one per node)


########################################
# 4. SST profiling points (clock / event / sync)
# We currently capture:
#   - clocks: per-component handler time (e.g., merlin.hr_router)
#   - events: per-event receive time (e.g., Ember, Firefly Nic)
#   - sync:   global SyncManager stats (time spent in parallel sync)
########################################

PROFILE_POINTS='\
clocks:sst.profile.handler.clock.time.steady(level=type)[clock];\
events:sst.profile.handler.event.time.steady(level=type,track_ports=true,profile_receives=true)[event];\
sync:sst.profile.sync.time.steady[sync]'


########################################
# 5. Run SST across 2 nodes with MPI via srun
#    - Slurm spawns `ranks` MPI processes over node1,node2
#    - Each rank runs SST with `threads` internal threads
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} hosts=${SLURM_JOB_NODELIST} \
ranks=${ranks} threads_per_rank=${threads} \
app=${app} groups=${g} jobs=${j} iters=${k} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT} \
profiling_points=${PROFILE_POINTS}" \
  | tee "${LOG_FILE}"

# Main SST invocation:
#   srun                        : launch MPI ranks across nodes under Slurm
#   sst --num-threads=threads   : threads inside each rank
#   --enable-profiling          : turn on profiling points above
#   "${APPPY}" -- ...           : pass network/halo parameters into the Python config
srun sst \
  --num-threads="${threads}" \
  --enable-profiling="${PROFILE_POINTS}" \
  "${APPPY}" -- \
    --app "${app}" \
    --groups "${g}" \
    --jobs "${j}" \
    --iters "${k}" \
    --link_bw "${LINK_BW}" \
    --router_latency="${ROUTER_LAT}" \
    --link_latency="${LINK_LAT}" \
  2>&1 | tee -a "${LOG_FILE}"

# Capture sst's exit code from the pipeline (index 0 = srun/sst, 1 = tee)
RET=${PIPESTATUS[0]}

echo "SST_RUN_COMPLETE job=${SLURM_JOB_ID} exit_code=${RET}" | tee -a "${LOG_FILE}"

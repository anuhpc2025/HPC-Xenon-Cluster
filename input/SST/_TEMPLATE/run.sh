#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --ntasks=1                      # One SST process
#SBATCH --cpus-per-task=16              # SST threads (matches manual command)
#SBATCH --time=01:00:00                 # Time limit hh:mm:ss
#SBATCH --nodes=1
#SBATCH --nodelist=node1
#SBATCH --output=/home/hpc/logs/%x-%j.out


########################################
# 1. Basic environment
########################################

ulimit -l unlimited
ulimit -n 65536

########################################
# 2. Paths & work dir
########################################

SST_WORKDIR=/home/hpc/Programs/sst-scc-practice/network
cd "${SST_WORKDIR}"

# The SST Python config that builds the Ember/Merlin network.
# Swap to a different topology/app config script if needed.
APPPY=./scc-network.py

# Per-run log directory + file
OUT_BASE=/home/hpc/sst-runs
OUT_DIR="${OUT_BASE}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}"
mkdir -p "${OUT_DIR}"
LOG_FILE="${OUT_DIR}/sst.log"

########################################
# 3. Parameters for application:
########################################

app="halo"
g=5                 # groups: increase to scale up the number of groups / traffic “clusters”
j=2                 # jobs: number of jobs per group 
k=2                 # iterations: Of halo exchange (higher k => longer simulation)

LINK_BW="25GB/s"    # Link bandwidth
ROUTER_LAT="100ns"  # Router latency
LINK_LAT="50ns"     # Link latency

threads="${SLURM_CPUS_PER_TASK}"

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
# 5. Run SST and tee output (logs survive cancellation)
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} host=$(hostname) threads=${threads} \
app=${app} groups=${g} jobs=${j} iters=${k} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT} \
profiling_points=${PROFILE_POINTS}" \
  | tee "${LOG_FILE}"

# Main SST invocation:
#   --num-threads="${threads}"      : use the Slurm cpus-per-task as SST thread count
#   --enable-profiling              : turn on the profiling points above
#   "${APPPY}"                      : call into the Python config script with workload knobs

sst \
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
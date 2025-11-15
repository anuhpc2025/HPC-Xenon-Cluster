#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --ntasks=1                      # One SST process
#SBATCH --cpus-per-task=4               # SST threads (matches manual command)
#SBATCH --time=00:05:00                 # Time limit hh:mm:ss
#SBATCH --nodes=1
#SBATCH --nodelist=node1
#SBATCH --output=/home/hpc/logs/%x-%j.out


########################################
# 1. Basic environment
########################################

# If you need modules for SST, uncomment:

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
# 3. Hard-coded workload (no GROUPS var!)
########################################

app="halo"
g=5          # groups
j=2          # jobs
k=2          # iterations

LINK_BW="25GB/s"    # Link bandwidth
ROUTER_LAT="100ns"  # Router latency
LINK_LAT="50ns"     # Link latency

threads="${SLURM_CPUS_PER_TASK}"

########################################
# 4. SST profiling points (clock / event / sync)
#    From SST-Profiling-Points.pdf:
#      name:type(params)[point]
#    point ∈ {clock,event,sync}
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

# Run SST, stream output to both Slurm stdout and LOG_FILE
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

# Capture sst's exit code from the pipeline
RET=${PIPESTATUS[0]}

echo "SST_RUN_COMPLETE job=${SLURM_JOB_ID} exit_code=${RET}" | tee -a "${LOG_FILE}"

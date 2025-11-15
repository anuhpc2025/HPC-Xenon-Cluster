#!/bin/bash
#SBATCH --job-name=sst-halo-hybrid      # Job name
#SBATCH --nodes=1
#SBATCH --nodelist=node1
#SBATCH --ntasks=2                      # 2 MPI ranks (one per socket)
#SBATCH --ntasks-per-node=2
#SBATCH --cpus-per-task=8               # 8 SST threads per rank  = 16 cores total
#SBATCH --time=00:05:00                 # Time limit hh:mm:ss
#SBATCH --output=/home/hpc/logs/%x-%j.out
#SBATCH --hint=nomultithread            # Use physical cores, not SMT

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

APPPY=./scc-network.py

# Per-run log directory + file
OUT_BASE=/home/hpc/sst-runs
OUT_DIR="${OUT_BASE}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}"
mkdir -p "${OUT_DIR}"
LOG_FILE="${OUT_DIR}/sst.log"

########################################
# 3. Workload parameters
########################################

app="halo"          # application: halo, sweep3D, etc.
g=5                 # groups
j=2                 # jobs
k=2                 # iterations

LINK_BW="25GB/s"    # Link bandwidth
ROUTER_LAT="100ns"  # Router latency
LINK_LAT="50ns"     # Link latency

# Hybrid layout: MPI ranks × threads
MPI_RANKS="${SLURM_NTASKS:-1}"
threads="${SLURM_CPUS_PER_TASK:-1}"
TOTAL_HW_THREADS=$(( MPI_RANKS * threads ))

# For any libs that pay attention to OMP_NUM_THREADS
export OMP_NUM_THREADS="${threads}"

########################################
# 4. SST profiling points (clock / event / sync)
########################################

PROFILE_POINTS='\
clocks:sst.profile.handler.clock.time.steady(level=type)[clock];\
events:sst.profile.handler.event.time.steady(level=type,track_ports=true,profile_receives=true)[event];\
sync:sst.profile.sync.time.steady[sync]'

########################################
# 5. Run SST via srun (hybrid MPI + threads)
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} host=$(hostname) \
mpi_ranks=${MPI_RANKS} threads_per_rank=${threads} total_threads=${TOTAL_HW_THREADS} \
app=${app} groups=${g} jobs=${j} iters=${k} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT} \
profiling_points=${PROFILE_POINTS}" | tee "${LOG_FILE}"

# srun launches one SST process per MPI rank; each uses --num-threads=${threads}
srun \
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

# Capture sst/srun's exit code from the pipeline
RET=${PIPESTATUS[0]}

echo "SST_RUN_COMPLETE job=${SLURM_JOB_ID} exit_code=${RET}" | tee -a "${LOG_FILE}"

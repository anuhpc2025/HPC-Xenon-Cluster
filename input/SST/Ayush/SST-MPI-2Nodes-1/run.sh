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

# --- Load HPC-X + UCX (same idea as HPL script) ---
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
export PATH=${HPCX_HOME}/ucx/bin:${HPCX_HOME}/ompi/bin:${PATH}
export LD_LIBRARY_PATH=${HPCX_HOME}/ucx/lib:${HPCX_HOME}/ompi/lib:${LD_LIBRARY_PATH}
load hpcx

########################################
# 2. Paths & work dir
########################################

SST_WORKDIR=/home/hpc/Programs/sst-scc-practice/network
cd "${SST_WORKDIR}"

APPPY=./scc-network.py

OUT_BASE=/home/hpc/sst-runs
OUT_DIR="${OUT_BASE}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}"
mkdir -p "${OUT_DIR}"
LOG_FILE="${OUT_DIR}/sst.log"


########################################
# 3. Parameters for application
########################################

app="halo"

g=5
j=10
k=5

LINK_BW="25GB/s"
ROUTER_LAT="100ns"
LINK_LAT="50ns"

threads="${SLURM_CPUS_PER_TASK}"   # 16
ranks="${SLURM_NTASKS}"            # 2


########################################
# 4. SST profiling points
########################################

PROFILE_POINTS='\
clocks:sst.profile.handler.clock.time.steady(level=type)[clock];\
events:sst.profile.handler.event.time.steady(level=type,track_ports=true,profile_receives=true)[event];\
sync:sst.profile.sync.time.steady[sync]'


########################################
# 5. Run SST across 2 nodes with MPI via mpirun
#    Slurm provides the allocation; Open MPI (HPC-X) uses plm_slurm.
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} hosts=${SLURM_JOB_NODELIST} \
ranks=${ranks} threads_per_rank=${threads} \
app=${app} groups=${g} jobs=${j} iters=${k} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT} \
profiling_points=${PROFILE_POINTS}" \
  | tee "${LOG_FILE}"

mpirun -np "${ranks}" \
  -x PATH -x LD_LIBRARY_PATH \
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

RET=${PIPESTATUS[0]}

echo "SST_RUN_COMPLETE job=${SLURM_JOB_ID} exit_code=${RET}" | tee -a "${LOG_FILE}"

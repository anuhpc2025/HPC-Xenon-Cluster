#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --nodes=2                       # Use 2 nodes
#SBATCH --ntasks-per-node=1            # 1 MPI rank per node (total ranks = 2)
#SBATCH --cpus-per-task=16             # 16 threads per rank
#SBATCH --time=01:00:00                # Time limit hh:mm:ss
#SBATCH --nodelist=node1,node2         # Explicit node list
#SBATCH --output=/home/hpc/logs/%x-%j.out
#SBATCH --hint=nomultithread

########################################
# 1. Base environment
########################################

# Load your usual shell environment (PATH, etc.)
source ~/.bashrc

########## HPC-X / MPI + UCX ##########
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64

# Put HPC-X MPI first in PATH, and its libs in LD_LIBRARY_PATH
export PATH=${HPCX_HOME}/ompi/bin:${PATH}
export LD_LIBRARY_PATH=${HPCX_HOME}/ucx/lib:${HPCX_HOME}/ompi/lib:${LD_LIBRARY_PATH}

# Initialize HPC-X stacks (UCX + OMPI)
source ${HPCX_HOME}/hpcx-init.sh
hpcx_load ucx ompi

# UCX / OMPI tuning (you can tweak later)
export UCX_TLS=rc_x,sm,self
export UCX_RNDV_SCHEME=put_zcopy
export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_btl=^vader,tcp,openib

# ulimits
ulimit -l unlimited
ulimit -n 65536

########################################
# 1b. SST runtime environment
########################################

# Match your working interactive env + sst-info search paths
export SST_CORE_HOME=/home/hpc/local/sstcore-15.0.0
export SST_ELEMENTS_HOME=/home/hpc/local/sstelements-15.0.0

# Element search path (directories where libmerlin.so, libfirefly.so, etc. live)
export SST_ELEMENT_SEARCHPATH=\
${SST_CORE_HOME}/lib/sstcore:\
${SST_ELEMENTS_HOME}/lib/sst-elements-library:\
/home/hpc/Downloads/sst-build/sst-elements/src/sst/elements/osseous

# Older-style variable some scripts/environments still use
export SST_ELEMENT_LIBRARY=${SST_ELEMENTS_HOME}/lib/sst-elements-library

# Make sure shared libs are visible too
export LD_LIBRARY_PATH=\
${SST_CORE_HOME}/lib:\
${SST_CORE_HOME}/lib/sstcore:\
${SST_ELEMENTS_HOME}/lib:\
${SST_ELEMENTS_HOME}/lib/sst-elements-library:\
${LD_LIBRARY_PATH}

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
# 3. Application parameters
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
# 4b. Sanity check SST inside the job (rank 0 node)
########################################

{
  echo "==== SST ENV CHECK (job=${SLURM_JOB_ID}) ===="
  which sst
  echo "SST_CORE_HOME=${SST_CORE_HOME}"
  echo "SST_ELEMENTS_HOME=${SST_ELEMENTS_HOME}"
  echo "SST_ELEMENT_SEARCHPATH=${SST_ELEMENT_SEARCHPATH}"
  echo
  sst-info firefly | head -n 15
  echo
  sst-info merlin  | head -n 15
  echo "============================================="
} | tee "${LOG_FILE}"

########################################
# 5. Run SST across 2 nodes with mpirun (HPC-X)
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} hosts=${SLURM_JOB_NODELIST} \
ranks=${ranks} threads_per_rank=${threads} \
app=${app} groups=${g} jobs=${j} iters=${k} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT} \
profiling_points=${PROFILE_POINTS}" \
  | tee -a "${LOG_FILE}"

mpirun \
  --map-by ppr:1:node:PE="${threads}" \
  --bind-to core \
  --report-bindings \
  -x PATH -x LD_LIBRARY_PATH \
  -x SST_CORE_HOME -x SST_ELEMENTS_HOME -x SST_ELEMENT_SEARCHPATH -x SST_ELEMENT_LIBRARY \
  -x UCX_TLS -x UCX_RNDV_SCHEME \
  -x OMPI_MCA_pml -x OMPI_MCA_osc -x OMPI_MCA_btl \
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

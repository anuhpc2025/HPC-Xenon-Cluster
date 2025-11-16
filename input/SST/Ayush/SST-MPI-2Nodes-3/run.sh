#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --nodes=2                       # Use 2 nodes
#SBATCH --ntasks-per-node=1            # 1 MPI rank per node  (total ranks = 2)
#SBATCH --cpus-per-task=16             # 16 threads per rank (use all cores per node)
#SBATCH --time=01:00:00                # Time limit hh:mm:ss
#SBATCH --nodelist=node1,node2         # Explicit node list
#SBATCH --output=/home/hpc/logs/%x-%j.out
#SBATCH --hint=nomultithread

########################################
# 1. Basic environment
########################################

# Load your normal shell env (modules, aliases, etc.)
source ~/.bashrc

# --- Load HPC-X + UCX (same idea as HPL script) ---
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
export LD_LIBRARY_PATH=${HPCX_HOME}/ucx/lib:${HPCX_HOME}/ompi/lib:${LD_LIBRARY_PATH}
export PATH=${HPCX_HOME}/ompi/bin:${PATH}

# Initialize HPC-X (UCX + OMPI)
source ${HPCX_HOME}/hpcx-init.sh
hpcx_load ucx ompi

# UCX / OMPI tuning (optional, matches HPL-style env)
export UCX_TLS=rc_x,sm,self
export UCX_RNDV_SCHEME=put_zcopy
export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_btl=^vader,tcp,openib

# Make sure each rank can lock memory & open enough files
ulimit -l unlimited
ulimit -n 65536

########################################
# 1b. SST runtime environment (from your working env)
########################################

export SST_CORE_HOME=/home/hpc/local/sstcore-15.0.0
export SST_ELEMENTS_HOME=/home/hpc/local/sstelements-15.0.0
export SST_ELEMENT_LIBRARY=${SST_ELEMENTS_HOME}/lib/sst-elements-library

# Ensure the core + elements libs are visible to the dynamic linker
export LD_LIBRARY_PATH=${SST_CORE_HOME}/lib:${SST_CORE_HOME}/lib/sstcore:${SST_ELEMENT_LIBRARY}:${LD_LIBRARY_PATH}

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
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} hosts=${SLURM_JOB_NODELIST} \
ranks=${ranks} threads_per_rank=${threads} \
app=${app} groups=${g} jobs=${j} iters=${k} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT} \
profiling_points=${PROFILE_POINTS}" \
  | tee "${LOG_FILE}"

mpirun \
  --map-by ppr:1:node:PE="${threads}" \
  --bind-to core \
  --report-bindings \
  -x PATH -x LD_LIBRARY_PATH \
  -x UCX_TLS -x UCX_RNDV_SCHEME \
  -x OMPI_MCA_pml -x OMPI_MCA_osc -x OMPI_MCA_btl \
  -x SST_CORE_HOME -x SST_ELEMENTS_HOME -x SST_ELEMENT_LIBRARY \
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

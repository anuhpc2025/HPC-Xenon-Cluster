#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --nodes=2                       # 3 nodes
#SBATCH --ntasks-per-node=1             # 1 MPI rank per node (total ranks = 3)
#SBATCH --cpus-per-task=8                # 1 thread per rank
#SBATCH --time=12:00:00                  # Time limit hh:mm:ss
#SBATCH --nodelist=node1,node2     # Explicit node list
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

# UCX / OMPI tuning (same style as your HPL script)
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

export SST_CORE_HOME=/home/hpc/local/sstcore-15.0.0
export SST_ELEMENTS_HOME=/home/hpc/local/sstelements-15.0.0

# Ensure sst/sst-info are on PATH from the local install
export PATH=${SST_CORE_HOME}/bin:${SST_ELEMENTS_HOME}/bin:${PATH}

# Core + elements libdirs
SST_CORE_LIBDIR="${SST_CORE_HOME}/lib/sstcore"
SST_ELEM_LIBDIR="${SST_ELEMENTS_HOME}/lib/sst-elements-library"

# Element search path (what sst/sst-info use to find libfirefly.so, libmerlin.so, etc.)
export SST_ELEMENT_SEARCHPATH="${SST_CORE_LIBDIR}:${SST_ELEM_LIBDIR}"

# Some environments still look at this:
export SST_ELEMENT_LIBRARY="${SST_ELEM_LIBDIR}"

# Ensure shared libs are visible to the dynamic linker
export LD_LIBRARY_PATH="${SST_CORE_HOME}/lib:${SST_CORE_LIBDIR}:${SST_ELEMENTS_HOME}/lib:${SST_ELEM_LIBDIR}:${LD_LIBRARY_PATH}"

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
j=2
k=5

LINK_BW="25GB/s"
ROUTER_LAT="100ns"
LINK_LAT="50ns"

threads="${SLURM_CPUS_PER_TASK}"  
ranks="${SLURM_NTASKS}"            

########################################
# 4. SST profiling points
########################################

PROFILE_POINTS='\
clocks:sst.profile.handler.clock.time.steady(level=type)[clock];\
events:sst.profile.handler.event.time.steady(level=type,track_ports=true,profile_receives=true)[event];\
sync:sst.profile.sync.time.steady[sync]'

########################################
# 5. Run SST
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} hosts=${SLURM_JOB_NODELIST} \
ranks=${ranks} threads_per_rank=${threads} \
app=${app} groups=${g} jobs=${j} iters=${k} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT}" 

GRAPH_DOT="${OUT_DIR}/halo_config_${SLURM_JOB_ID}.dot"
GRAPH_PDF="${OUT_DIR}/halo_config_${SLURM_JOB_ID}.pdf"

echo "SST_CONFIG_GRAPH_START job=${SLURM_JOB_ID} dot=${GRAPH_DOT}" | tee -a "${LOG_FILE}"


mpirun \
  --map-by ppr:1:node:PE="${threads}" \
  --bind-to core \
  --report-bindings \
  --output-dot="${GRAPH_DOT}" \
  -x PATH -x LD_LIBRARY_PATH \
  -x SST_CORE_HOME -x SST_ELEMENTS_HOME -x SST_ELEMENT_SEARCHPATH -x SST_ELEMENT_LIBRARY \
  -x UCX_TLS -x UCX_RNDV_SCHEME \
  -x OMPI_MCA_pml -x OMPI_MCA_osc -x OMPI_MCA_btl \
  sst \
    --add-lib-path="${SST_CORE_LIBDIR}" \
    --add-lib-path="${SST_ELEM_LIBDIR}" \
    --num-threads="${threads}" \
    --enable-profiling="${PROFILE_POINTS}" \
    "${APPPY}" -- \
      --app "${app}" \
      --groups "${g}" \
      --jobs "${j}" \
      --iters "${k}" \
      --link_bw="${LINK_BW}" \
      --router_latency="${ROUTER_LAT}" \
      --link_latency="${LINK_LAT}" \
  2>&1 | tee -a "${LOG_FILE}"

# show first few lines of the DOT file in the Slurm log
echo "==== First lines of ${GRAPH_DOT} ====" | tee -a "${LOG_FILE}"
head -n 40 "${GRAPH_DOT}" | tee -a "${LOG_FILE}"
echo "=====================================" | tee -a "${LOG_FILE}"
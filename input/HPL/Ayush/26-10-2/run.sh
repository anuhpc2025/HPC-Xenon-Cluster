#!/bin/bash
#SBATCH --job-name=hpl-test             # Job name
#SBATCH --nodes=4                       # Number of nodes
#SBATCH --nodelist=node1,node2,node3,node4
#SBATCH --ntasks=128                    # Total MPI ranks
#SBATCH --ntasks-per-node=32            # Ranks per node
#SBATCH --cpus-per-task=1               # Cores per rank
#SBATCH --time=12:00:00                 # Walltime

######## 1. Load HPC-X (Open MPI + UCX 1.19) ########

# Point to your HPC-X install
export HPCX_ROOT=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64

# Load the HPC-X environment (sets some MPI/UCX bits)
source ${HPCX_ROOT}/hpcx-init.sh
hpcx_load

# Force PATH / LD_LIBRARY_PATH so UCX 1.19 + this OpenMPI stay first
export PATH=${HPCX_ROOT}/ucx/bin:${HPCX_ROOT}/ompi/bin:${PATH}
export LD_LIBRARY_PATH=${HPCX_ROOT}/ucx/lib:${HPCX_ROOT}/ompi/lib:${LD_LIBRARY_PATH}

######## 2. AOCL BLIS (CPU math library for HPL DGEMM) ########

export AOCLROOT=/opt/AMD/aocl-5.1.0/5.1.0/gcc
# Put AOCL BLIS on the library path (goes before system libs, after HPC-X)
export LD_LIBRARY_PATH=${AOCLROOT}/lib:${LD_LIBRARY_PATH}

# BLIS / OpenMP tuning for AOCL on EPYC
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=close
export OMP_PLACES=cores

export BLIS_ENABLE_OPENMP=1
export BLIS_CPU_ARCH=ZEN3
export BLIS_DYNAMIC_SCHED=1

######## 3. UCX / MPI transport tuning for InfiniBand ########
# These help MPI point-to-point / collectives use IB via UCX efficiently

export UCX_TLS=rc_x,sm,self
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_PCI_RELAXED_ORDERING=on   # harmless if NIC says "unsupported"

# These tell Open MPI to speak UCX everywhere (avoid legacy BTL paths)
export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
# optional: strongly steer it off the old BTL transports
export OMPI_MCA_btl=^openib,tcp,uct,vader,sm,self

######## 4. System prep ########

# Unlimited pinned memory for RDMA
ulimit -l unlimited
# Higher file descriptor limit (lots of ranks / sockets)
ulimit -n 65536

# Flush FS caches just before the big run
sync

######## 5. Run HPL ########
# IMPORTANT:
#   - We pass `-x PATH -x LD_LIBRARY_PATH` so *all nodes* inherit the HPC-X env
#   - We also pass all tuning envs so every rank sees the same config
#   - `ppr:32:node` matches 32 ranks per node in Slurm (4 nodes * 32 = 128)

mpirun \
  --map-by ppr:32:node:PE=1 \
  --rank-by core \
  --bind-to core \
  --report-bindings \
  -x PATH \
  -x LD_LIBRARY_PATH \
  -x AOCLROOT \
  -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x BLIS_ENABLE_OPENMP -x BLIS_CPU_ARCH -x BLIS_DYNAMIC_SCHED \
  -x UCX_TLS -x UCX_IB_GPU_DIRECT_RDMA -x UCX_MEMTYPE_CACHE \
  -x UCX_RNDV_SCHEME -x UCX_IB_PCI_RELAXED_ORDERING \
  -x OMPI_MCA_pml -x OMPI_MCA_osc -x OMPI_MCA_btl \
  ./xhpl

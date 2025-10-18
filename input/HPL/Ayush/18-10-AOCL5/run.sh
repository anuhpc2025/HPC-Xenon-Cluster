#!/bin/bash
#SBATCH --job-name=hpl-128mpi
#SBATCH --nodes=4
#SBATCH --nodelist=node1,node2,node3,node4
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --time=02:00:00
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --output=hpl-128mpi-%j.out
set -euo pipefail

# ===== AOCL =====
export AOCL_DIR="$HOME/aocl/5.1.0/gcc"
export LD_LIBRARY_PATH="$AOCL_DIR/lib:${LD_LIBRARY_PATH:-}"

# ===== HPC-X (Open MPI + UCX) =====
export HPCX_HOME="/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64"
export HPCX_ENABLE_NCCLNET_PLUGIN=0
source "$HPCX_HOME/hpcx-init.sh"; hpcx_load
export PATH="$HPCX_HOME/ompi/bin:$PATH"
export LD_LIBRARY_PATH="$HPCX_HOME/ompi/lib:$HPCX_HOME/ucx/lib:$LD_LIBRARY_PATH"

# ===== UCX over IB (CPU only) =====
export UCX_TLS="rc_x,sm,self"
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
unset UCX_IB_GPU_DIRECT_RDMA   # GPU-only feature

# ===== Pure MPI (no BLIS threads) =====
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=close
export OMP_PLACES=cores

ulimit -l unlimited
ulimit -n 65536

mpirun \
  --mca pml ucx --mca btl ^vader,tcp,openib,uct \
  --map-by ppr:32:node:pe=1 --bind-to core --report-bindings \
  -x LD_LIBRARY_PATH -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x UCX_TLS -x UCX_MEMTYPE_CACHE -x UCX_RNDV_SCHEME \
  ./xhpl

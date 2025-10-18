#!/bin/bash
#SBATCH --job-name=hpl-hybrid
#SBATCH --nodes=4
#SBATCH --nodelist=node1,node2,node3,node4
#SBATCH --ntasks-per-node=4          # 1 MPI rank per L3 cache
#SBATCH --cpus-per-task=8            # 8 OpenMP threads per rank
#SBATCH --time=02:00:00
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --output=hpl-hybrid-%j.out

set -euo pipefail

# === AOCL (BLIS/LAPACK) ===
export AOCL_DIR="$HOME/aocl/5.1.0/gcc"
export LD_LIBRARY_PATH="$AOCL_DIR/lib:${LD_LIBRARY_PATH:-}"

# === HPC-X (Open MPI + UCX) ===
export HPCX_HOME="/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64"
export HPCX_ENABLE_NCCLNET_PLUGIN=0
source "$HPCX_HOME/hpcx-init.sh"; hpcx_load
export PATH="$HPCX_HOME/ompi/bin:$PATH"
export LD_LIBRARY_PATH="$HPCX_HOME/ompi/lib:$HPCX_HOME/ucx/lib:$LD_LIBRARY_PATH"

# === UCX over IB (CPU HPL) ===
export UCX_TLS="rc_x,sm,self"
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy

# === OpenMP/BLIS threading ===
export OMP_NUM_THREADS=8
export OMP_PROC_BIND=TRUE
export OMP_PLACES=cores
export BLIS_IC_NT=8
export BLIS_JC_NT=1

ulimit -l unlimited
ulimit -n 65536

# 16 ranks total = 4 nodes × 4 ranks/node (1 per L3), 8 threads each
mpirun -np 16 --report-bindings \
  --map-by ppr:1:l3cache:pe=8 --bind-to core \
  ./xhpl

#!/bin/bash
#SBATCH --job-name=hpl-128ranks
#SBATCH --nodes=4
#SBATCH --nodelist=node1,node2,node3,node4
#SBATCH --ntasks-per-node=32        # 32 ranks per node
#SBATCH --ntasks=128                # total ranks = 128 (= 4*32)
#SBATCH --cpus-per-task=1           # pure MPI
#SBATCH --time=02:00:00
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --output=hpl-%j.out

set -euo pipefail

# === HPC-X (Open MPI + UCX) ===
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source "$HPCX_HOME/hpcx-init.sh"; hpcx_load
export PATH=$HPCX_HOME/ompi/bin:$PATH
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$LD_LIBRARY_PATH

# === AOCL BLIS (OK with threads=1) ===
export AOCL_DIR=$HOME/aocl
export LD_LIBRARY_PATH=$AOCL_DIR/5.1.0/gcc/lib:$LD_LIBRARY_PATH

# === OpenMP (disable threading) ===
export OMP_NUM_THREADS=1
export BLIS_NUM_THREADS=1
export OMP_PROC_BIND=true
export OMP_PLACES=cores

# === UCX (CPU-only) ===
export UCX_TLS=rc_x,sm,self
export UCX_RNDV_SCHEME=put_zcopy

ulimit -l unlimited
ulimit -n 65536

cd $HOME/hpl-2.3/testing
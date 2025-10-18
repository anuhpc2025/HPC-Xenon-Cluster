#!/bin/bash
#SBATCH --job-name=hpl-128mpi
#SBATCH --nodes=4
#SBATCH --nodelist=node1,node2,node3,node4
#SBATCH --ntasks=128                 # 32 ranks/node
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --time=02:00:00
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --output=hpl-128mpi-%j.out
set -euo pipefail

# === HPC-X (Open MPI + UCX) ===
export HPCX_HOME="/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64"
source "$HPCX_HOME/hpcx-init.sh"; hpcx_load
export PATH="$HPCX_HOME/ompi/bin:$PATH"
export LD_LIBRARY_PATH="$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:${LD_LIBRARY_PATH:-}"

# === AOCL (BLIS/LAPACK) ===
export AOCL_DIR="$HOME/aocl/5.1.0/gcc"
export LD_LIBRARY_PATH="$AOCL_DIR/lib:$LD_LIBRARY_PATH"

# === UCX over IB (CPU HPL) ===
export UCX_TLS="rc_x,sm,self"
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy

# === OpenMP/BLIS threading (pure MPI) ===
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=close
export OMP_PLACES=cores
export BLIS_IC_NT=1
export BLIS_JC_NT=1

ulimit -l unlimited
ulimit -n 65536

# Launch using the SLURM allocation (either way works):
# Recommended under Slurm to avoid "slots" complaints:
srun --mpi=pmix -n 128 ./xhpl


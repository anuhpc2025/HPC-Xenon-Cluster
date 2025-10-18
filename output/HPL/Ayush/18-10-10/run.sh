#!/bin/bash
#SBATCH --job-name=hpl-aocl
#SBATCH --nodes=4
#SBATCH --nodelist=node1,node2,node3,node4
#SBATCH --ntasks-per-node=2            # 2 ranks per node → total 8 ranks
#SBATCH --cpus-per-task=16             # 16 threads per rank
#SBATCH --time=10:00:00
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --output=hpl-%j.out

# Strict mode (keep -u, since we'll define the needed vars first)
set -euo pipefail

# === HPC-X (Open MPI + UCX) ===
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
# Prevent hpcx-init.sh from tripping on nounset:
export HPCX_ENABLE_NCCLNET_PLUGIN=0
# (Optional but harmless on CPU-only runs)
export HPCX_OSU_ENABLE=0
export HPCX_MPI_TESTS_ENABLE=0

# Now it’s safe to source with -u
source "$HPCX_HOME/hpcx-init.sh"
hpcx_load
export PATH="$HPCX_HOME/ompi/bin:$PATH"

# === AOCL BLIS (dynamic) ===
export AOCL_DIR="$HOME/aocl"
export LD_LIBRARY_PATH="$AOCL_DIR/5.1.0/gcc/lib:$LD_LIBRARY_PATH"

# === UCX (CPU only; no CUDA lanes) ===
export UCX_TLS=rc_x,sm,self
export UCX_IB_PCI_RELAXED_ORDERING=on
export UCX_RNDV_SCHEME=put_zcopy
export UCX_MEMTYPE_CACHE=n

# Make sure we don't accidentally preload NCCL/NVSHMEM, etc.
unset LD_PRELOAD

# === OpenMP / threading ===
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export OMP_PROC_BIND=close
export OMP_PLACES=cores
# export BLIS_NUM_THREADS=$OMP_NUM_THREADS  # optional

# === Ulimits ===
ulimit -l unlimited
ulimit -n 65536

# === Run HPL ===
mpirun --mca pml ucx \
       --bind-to core \
       --map-by ppr:2:node:PE=${SLURM_CPUS_PER_TASK} \
       --report-bindings \
       ./xhpl

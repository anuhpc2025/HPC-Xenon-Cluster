#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --nodes=4
#SBATCH --nodelist=node1,node2,node3,node4    
#SBATCH --ntasks=8                # 4 ranks per node × 4 nodes = 16 total
#SBATCH --ntasks-per-node=2
#SBATCH --cpus-per-task=16         # CPU cores per MPI task
#SBATCH --time=10:00:00           # Time limit hh:mm:ss
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --output=hpl-%j.out

# Load MPI module (adjust for your system)
# module load openmpi
set -euo pipefail

# === HPC-X (Open MPI + UCX) ===
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source "$HPCX_HOME/hpcx-init.sh"
hpcx_load

# Keep HPC-X first
export PATH="$HPCX_HOME/ompi/bin:$PATH"

# === AOCL BLIS (dynamic) ===
# Adjust AOCL_DIR if installed elsewhere (e.g., /opt/AMD/aocl)
export AOCL_DIR="$HOME/aocl"
export LD_LIBRARY_PATH="$AOCL_DIR/5.1.0/gcc/lib:$LD_LIBRARY_PATH"

# (Optional) If you linked against libflame as well:
# export LD_LIBRARY_PATH="$AOCL_DIR/5.1.0/gcc/libflame/lib:$LD_LIBRARY_PATH"

# === UCX (CPU only; no CUDA lanes) ===
export UCX_TLS=rc_x,sm,self           # IB RC + shared memory + self
export UCX_IB_PCI_RELAXED_ORDERING=on
export UCX_RNDV_SCHEME=put_zcopy
export UCX_MEMTYPE_CACHE=n            # avoid memtype probing for CPU-only

# Make sure we don't accidentally preload NCCL/NVSHMEM etc.
unset LD_PRELOAD

# DO NOT append CUDA/NCCL/NVSHMEM paths for CPU HPL
# (removes nccl/nvshmem from LD_LIBRARY_PATH to avoid UCX GPU transports)

# === OpenMP/Threading for AOCL BLIS ===
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK   # 16
export OMP_PROC_BIND=close
export OMP_PLACES=cores
# BLIS respects OMP_NUM_THREADS; BLIS_NUM_THREADS is optional:
# export BLIS_NUM_THREADS=$OMP_NUM_THREADS

# === Ulimits ===
ulimit -l unlimited
ulimit -n 65536

# === Sanity checks (uncomment if you want to verify once) ===
# echo "AOCL libs:"; ls -1 "$AOCL_DIR/5.1.0/gcc/lib" | head
# echo "xhpl links:"; ldd ./xhpl | egrep 'blis|flame|omp|ucx|mpi'

# === Run HPL ===
# Map 2 ranks per node, each rank gets PE=16 cores; bind ranks to cores.
# --report-bindings helps confirm the placement.
mpirun --mca pml ucx \
       --bind-to core \
       --map-by ppr:2:node:PE=${SLURM_CPUS_PER_TASK} \
       --report-bindings \
       ./xhpl
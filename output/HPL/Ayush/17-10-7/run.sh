#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --nodes=2
#SBATCH --nodelist=node1,node2    # only nodes with HPC-X installed
#SBATCH --ntasks=4                # 2 ranks per node × 2 nodes = 4 total
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=8        # CPU cores (threads) per MPI task
#SBATCH --time=10:00:00           # Time limit hh:mm:ss

# Load MPI module (adjust for your system)
# module load openmpi

# Load HPCX (define explicitly; don't rely on ~/.bashrc order)
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source "$HPCX_HOME/hpcx-init.sh"
hpcx_load   # ensures HPC-X Open MPI/UCX are first in PATH/LD_LIBRARY_PATH

# ---- GPU/NCCL section (not used for CPU HPL) ----
unset LD_PRELOAD
# Do NOT prepend /usr/lib or CUDA/NCCL paths; keep HPC-X UCX first

# OMPI / UCX tuning (CPU transports only)
export UCX_TLS=rc_x,sm,self
export UCX_NET_DEVICES=mlx5_0:1
export UCX_IB_PCI_RELAXED_ORDERING=auto
MPIRUN_FLAGS="--mca pml ucx --mca btl ^vader,tcp,openib,uct"

# Threaded BLAS / OpenMP (match Slurm)
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-8}
export OMP_PROC_BIND=close
export OMP_PLACES=cores
export MKL_NUM_THREADS=$OMP_NUM_THREADS
export OPENBLAS_NUM_THREADS=$OMP_NUM_THREADS

# Ulimits
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
# Map 2 ranks per node; give each rank 16 cores; pin threads to cores
mpirun $MPIRUN_FLAGS \
  --map-by ppr:4:node:PE=${SLURM_CPUS_PER_TASK:-8} \
  --bind-to core --report-bindings \
  ./xhpl

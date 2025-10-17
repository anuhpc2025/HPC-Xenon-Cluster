#!/bin/bash
#SBATCH --job-name=hpl-test
#SBATCH --nodes=2
#SBATCH --nodelist=node1,node2           # only nodes with HPC-X installed
#SBATCH --ntasks-per-node=2              # 2 ranks per node
#SBATCH --cpus-per-task=32               # threads per rank
#SBATCH --time=10:00:00

# 0) Define HPC-X explicitly (don’t rely on ~/.bashrc)
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64

# 1) Load HPC-X LAST so its UCX/OMPI are first in PATH/LD_LIBRARY_PATH
source "$HPCX_HOME/hpcx-init.sh"
hpcx_load    # sets PATH/LD_LIBRARY_PATH to HPC-X stacks

# 2) UCX (CPU transports only) + UCX PML
export UCX_TLS=rc_x,sm,self
export UCX_NET_DEVICES=mlx5_0:1
export UCX_IB_PCI_RELAXED_ORDERING=auto
MPIRUN_FLAGS="--mca pml ucx --mca btl ^vader,tcp,openib,uct"

# 3) Threaded BLAS/OpenMP
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-32}
export OMP_PROC_BIND=close
export OMP_PLACES=cores
export MKL_NUM_THREADS=$OMP_NUM_THREADS
export OPENBLAS_NUM_THREADS=$OMP_NUM_THREADS

# 4) (No extra /usr/lib injections; no NCCL/CUDA paths for CPU HPL)

# 5) Run: one rank per socket, pin its 32 threads
mpirun $MPIRUN_FLAGS \
  --map-by socket:PE=${SLURM_CPUS_PER_TASK:-32} --bind-to core \
  --report-bindings \
  ./xhpl

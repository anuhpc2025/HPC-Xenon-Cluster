#!/bin/bash
#SBATCH --job-name=hpl-cpu
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=4          # 4 MPI ranks/node
#SBATCH --cpus-per-task=8            # 8 threads per rank ⇒ 32 cores/node
#SBATCH --time=10:00:00
#SBATCH --exclusive

module purge 2>/dev/null || true
unset LD_PRELOAD
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source "$HPCX_HOME/hpcx-init.sh"
hpcx_load ompi ucx

# UCX (IB + SHM only)
export UCX_TLS=rc_x,sm,self
export UCX_MEMTYPE_CACHE=n
export UCX_IB_PCI_RELAXED_ORDERING=off
export OMPI_MCA_pml=ucx
export OMPI_MCA_btl=^openib

# Threading
export OMP_NUM_THREADS=8
export OMP_PROC_BIND=close
export OMP_PLACES=cores

ulimit -l unlimited
ulimit -n 65536

# Run
mpirun --map-by ppr:4:node:pe=8 --bind-to core ./xhpl
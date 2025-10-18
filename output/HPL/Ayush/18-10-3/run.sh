#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --nodes=4
#SBATCH --nodelist=node1,node2,node3,node4   
#SBATCH --ntasks-per-node=2      # Number of MPI ranks per node
#SBATCH --ntasks=8                # 4 ranks per node × 4 nodes = 16 total
#SBATCH --cpus-per-task=16         # CPU cores per MPI task
#SBATCH --time=10:00:00           # Time limit hh:mm:ss

# Load MPI module (adjust for your system)
# module load openmpi

export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source "$HPCX_HOME/hpcx-init.sh"
hpcx_load
# Make sure we’re using HPC-X MPI/UCX, not system libs
export PATH=$HPCX_HOME/ompi/bin:$PATH
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$LD_LIBRARY_PATH

# === AOCL BLIS (threaded) ===
export AOCL_DIR=$HOME/aocl
# You can either source the config or set the path explicitly:
# source $AOCL_DIR/5.1.0/gcc/amd-libs.cfg
export LD_LIBRARY_PATH=$AOCL_DIR/5.1.0/gcc/lib:$LD_LIBRARY_PATH

# === OpenMP threads & pinning (match cpus-per-task) ===
export OMP_NUM_THREADS=16
export OMP_PROC_BIND=true
export OMP_PLACES=cores

# === UCX for CPU-only HPL ===
export UCX_TLS=rc_x,sm,self
export UCX_RNDV_SCHEME=put_zcopy
# Leave PCI relaxed ordering off unless your mlx5 reports support
# export UCX_IB_PCI_RELAXED_ORDERING=on

# === Ulimits ===
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun -np 8 --map-by ppr:2:node:pe=16 --bind-to core ./xhpl
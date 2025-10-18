#!/bin/bash
#SBATCH --job-name=hpl-test          # Job name
#SBATCH --ntasks=128                 # Total MPI tasks
#SBATCH --ntasks-per-node=32         # MPI tasks per node
#SBATCH --cpus-per-task=1            # CPU cores per MPI task
#SBATCH --time=10:00:00              # Time limit hh:mm:ss
#SBATCH --nodes=4                    # Number of nodes
#SBATCH --nodelist=node1,node2,node3,node4

# Load HPCX
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# === AOCL BLIS Setup ===
export AOCL_DIR=$HOME/aocl
export LD_LIBRARY_PATH=$AOCL_DIR/5.1.0/gcc/lib:$LD_LIBRARY_PATH

# === OpenMP/BLIS threading for EPYC 7313 ===
# EPYC 7313: 16 cores per CPU, 2 CPUs per node = 32 cores/node
# With 32 MPI ranks per node, each rank gets 1 core
# Set threads to 1 for pure MPI approach
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=TRUE
export OMP_PLACES=cores
export BLIS_IC_NT=1
export BLIS_JC_NT=1
export BLIS_JR_NT=1
export BLIS_IR_NT=1

# === UCX over IB (CPU HPL) ===
export UCX_TLS=rc_x,sm,self
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy

# === BLIS optimization flags ===
export BLIS_ARCH_TYPE=zen3
export BLIS_NUM_THREADS=1

# Ulimits
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program with binding
mpirun --bind-to core --map-by socket:PE=1 ./xhpl
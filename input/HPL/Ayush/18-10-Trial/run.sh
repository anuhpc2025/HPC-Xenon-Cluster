#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --nodes=4                 # Number of nodes
#SBATCH --nodelist=node1,node2,node3,node4    # nodes 1 and 2 are the only ones with hpcx for now
#SBATCH --ntasks-per-node=32       # MPI tasks per node
#SBATCH --cpus-per-task=1         # CPU cores per MPI task
#SBATCH --time=12:00:00           # Time limit hh:mm:ss
#SBATCH --exclusive
#SBATCH --hint=nomultithread
#SBATCH --output=hpl-128mpi-%j.out

# Load MPI module (adjust for your system)
# module load openmpi

# === AOCL paths ===
export AOCL_DIR="$HOME/aocl/5.1.0/gcc"
export LD_LIBRARY_PATH="$AOCL_DIR/lib:${LD_LIBRARY_PATH}"

# === HPC-X (Open MPI + UCX) ===
export HPCX_HOME="/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64"
export HPCX_ENABLE_NCCLNET_PLUGIN=0
source "$HPCX_HOME/hpcx-init.sh"; hpcx_load
export PATH="$HPCX_HOME/ompi/bin:$PATH"
export LD_LIBRARY_PATH="$HPCX_HOME/ompi/lib:$HPCX_HOME/ucx/lib:$LD_LIBRARY_PATH"

# === UCX over IB (safe, performant defaults) ===
export UCX_TLS="rc_x,sm,self"
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy

# === BLIS/OpenMP: pure MPI → 1 thread ===
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=close
export OMP_PLACES=cores

ulimit -l unlimited
ulimit -n 65536

# Note: be explicit about UCX PML; bind to cores
mpirun \
  --mca pml ucx --mca btl ^openib \
  --map-by ppr:32:node:pe=1 --bind-to core --report-bindings \
  -x LD_LIBRARY_PATH -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x UCX_TLS -x UCX_MEMTYPE_CACHE -x UCX_RNDV_SCHEME \
  ./xhpl
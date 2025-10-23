#!/bin/bash
#SBATCH --job-name=hpl-test
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --nodelist=node1,node2,node3,node4

# --- Clean env ---
module purge 2>/dev/null || true
unset LD_PRELOAD

# --- HPC-X (shared across nodes) ---
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source "$HPCX_HOME/hpcx-init.sh"
hpcx_load

# Keep HPC-X first in search order
export PATH="$HPCX_HOME/ompi/bin:$PATH"
export LD_LIBRARY_PATH="$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$HPCX_HOME/hcoll/lib:${LD_LIBRARY_PATH}"

# --- AOCL BLIS (CPU DGEMM) ---
export AOCLROOT=/opt/AMD/aocl-5.1.0/5.1.0/gcc
export LD_LIBRARY_PATH="${AOCLROOT}/lib:${LD_LIBRARY_PATH}"
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=true
export OMP_PLACES=cores
export BLIS_ENABLE_OPENMP=1
export BLIS_CPU_EXT=ZEN3
export BLIS_DYNAMIC_SCHED=0

# --- UCX / Open MPI ---
# If you have IB/RoCE:
export UCX_TLS=rc_x,shm,self
# export UCX_NET_DEVICES=mlx5_0:1     # set to your actual device
# If Ethernet-only, use instead:
# export UCX_TLS=shm,tcp,self
# export UCX_SOCKADDR_TLS_PRIORITY=sockcm

export OMPI_MCA_pml=ucx
export OMPI_MCA_btl=^openib,tcp,uct
export OMPI_MCA_osc=ucx

# --- Ulimits ---
ulimit -l unlimited
ulimit -n 65536

# --- Sanity check: make sure every node sees HPC-X UCX (>=1.19) ---
srun -N4 -n4 bash -lc 'echo "== $HOSTNAME =="; ucx_info -v | head -3; ldd $(which mpirun) | egrep "ucx|mpi|pmix"'

# --- Run HPL ---
mpirun \
  --map-by ppr:16:socket:PE=1 --rank-by core --bind-to core --report-bindings \
  -x LD_LIBRARY_PATH -x PATH \
  -x AOCLROOT -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x BLIS_ENABLE_OPENMP -x BLIS_CPU_EXT -x BLIS_DYNAMIC_SCHED \
  -x OMPI_MCA_pml -x OMPI_MCA_osc -x OMPI_MCA_btl \
  -x UCX_TLS -x UCX_NET_DEVICES -x UCX_SOCKADDR_TLS_PRIORITY \
  ./xhpl

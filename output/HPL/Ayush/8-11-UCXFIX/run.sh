#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=128              # Total MPI tasks
#SBATCH --ntasks-per-node=32       # MPI tasks per node
#SBATCH --cpus-per-task=1         # CPU cores per MPI task
#SBATCH --time=12:00:00           # Time limit hh:mm:ss
#SBATCH --nodes=4                 # Number of nodes

# Load MPI module (adjust for your system)
# module load openmpi

# Load HPCX
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# === AOCL BLIS ===
export AOCLROOT=/opt/AMD/aocl-5.1.0/5.1.0/gcc
export LD_LIBRARY_PATH=${AOCLROOT}/lib:$LD_LIBRARY_PATH


# ---- NCCL choice: use system 2.27.7 ----
export LD_LIBRARY_PATH=${HPCX_HOME}/ucx/lib:${HPCX_HOME}/ompi/lib:${AOCLROOT}/lib:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
export PATH=${HPCX_HOME}/ompi/bin:${HPCX_HOME}/ucx/bin:$PATH


export OMP_NUM_THREADS=1
export OMP_PROC_BIND=true
export OMP_PLACES=cores
export BLIS_ENABLE_OPENMP=1
export BLIS_CPU_EXT=ZEN3        
export BLIS_DYNAMIC_SCHED=0


export LD_PRELOAD=${HPCX_HOME}/ucx/lib/libucp.so.0:${HPCX_HOME}/ucx/lib/libucs.so.0


# OMPI / UCX tuning
export UCX_TLS=rc_x,sm,self
export UCX_NET_DEVICES=mlx5_0:1
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
unset UCX_IB_PCI_RELAXED_ORDERING
unset UCX_IB_GPU_DIRECT_RDMA

# Ulimits
ulimit -l unlimited
ulimit -n 65536
sync 

# Run the MPI program
mpirun \
  --map-by ppr:32:node:PE=1 --rank-by core --bind-to core --report-bindings \
  -x LD_LIBRARY_PATH -x PATH \
  -x AOCLROOT -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x BLIS_ENABLE_OPENMP -x BLIS_CPU_EXT -x BLIS_DYNAMIC_SCHED \
  -x OMPI_MCA_pml -x OMPI_MCA_osc -x OMPI_MCA_btl \
  -x UCX_TLS -x UCX_NET_DEVICES \
  ./xhpl
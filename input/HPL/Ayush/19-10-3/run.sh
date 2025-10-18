#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=128              # Total MPI tasks
#SBATCH --ntasks-per-node=32       # MPI tasks per node
#SBATCH --cpus-per-task=1         # CPU cores per MPI task
#SBATCH --time=14:00:00           # Time limit hh:mm:ss
#SBATCH --nodes=4                 # Number of nodes
#SBATCH --nodelist=node1,node2,node3,node4    # nodes 1 and 2 are the only ones with hpcx for now

# Load MPI module (adjust for your system)
# module load openmpi

# Load HPCX
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$LD_LIBRARY_PATH
export PATH=$HPCX_HOME/ompi/bin:$PATH
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# === AOCL BLIS (threaded) ===
export AOCL_DIR=$HOME/aocl
export LD_LIBRARY_PATH=$AOCL_DIR/5.1.0/gcc/lib:$LD_LIBRARY_PATH

export BLIS_JC_NT=1               # no outer-level parallelism
export BLIS_IC_NT=$OMP_NUM_THREADS  # inner parallelism = number of threads (4)
export BLIS_JR_NT=1
export BLIS_IR_NT=1

# ---- NCCL choice: use system 2.27.7 ----
unset LD_PRELOAD
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

export OMP_NUM_THREADS=1          # 4 threads per MPI rank (match --cpus-per-task)
export OMP_PROC_BIND=true         # bind threads to cores
export OMP_PLACES=cores           # define OpenMP threads placement on cores

# Optional: add CUDA & other NVIDIA libs, but *not* /opt/.../lib/nccl
export LD_LIBRARY_PATH=/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/omp:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/nvshmem/12:$LD_LIBRARY_PATH

# OMPI / UCX tuning
export UCX_TLS=rc_x,sm,self
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_PCI_RELAXED_ORDERING=on 

# Ulimits
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun ./xhpl

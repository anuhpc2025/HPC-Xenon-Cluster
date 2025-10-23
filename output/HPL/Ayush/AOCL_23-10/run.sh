#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=128              # Total MPI tasks
#SBATCH --ntasks-per-node=32       # MPI tasks per node
#SBATCH --cpus-per-task=1         # CPU cores per MPI task
#SBATCH --time=12:00:00           # Time limit hh:mm:ss
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

# ---- NCCL choice: use system 2.27.7 ----
unset LD_PRELOAD
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH


export OMP_NUM_THREADS=1          # 4 threads per MPI rank (match --cpus-per-task)
export OMP_PROC_BIND=true         # bind threads to cores
export OMP_PLACES=cores           # define OpenMP threads placement on cores


# === AOCL BLIS ===
export AOCLROOT=/opt/AMD/aocl-5.1.0/5.1.0/gcc
export LD_LIBRARY_PATH=$AOCLROOT/lib:$LD_LIBRARY_PATH

export BLIS_NUM_THREADS=$OMP_NUM_THREADS
export BLIS_ENABLE_OPENMP=1
export BLIS_CPU_EXT=ZEN3
export BLIS_DYNAMIC_SCHED=0
export BLIS_JC_NT=1
export BLIS_IC_NT=8
export BLIS_PC_NT=1
export BLIS_KC_NT=1

# Optional: add CUDA & other NVIDIA libs, but *not* /opt/.../lib/nccl
export LD_LIBRARY_PATH=/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/omp:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/nvshmem/12:$LD_LIBRARY_PATH


# Ulimits
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun ./xhpl
#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=8                # Total MPI tasks - 4 x 4
#SBATCH --ntasks-per-node=4       # balance tasks across nodes - 1 per gpu
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --nodes=2                 #
#SBATCH --nodelist=node1,node2    # nodes 1 and 2 are the only ones with hpcx for now

# Load hpcx module - and everything else we need for that matter
source ~/.bashrc

# hpc-x
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$LD_LIBRARY_PATH
export PATH=$HPCX_HOME/ompi/bin:$PATH
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# nvidia
export CUDA_VISIBLE_DEVICES=0,1,2,3
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1
export LD_LIBRARY_PATH=/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/omp:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nccl:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/nvshmem/12:$LD_LIBRARY_PATH

#testing
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun ./xhpl-nvidia
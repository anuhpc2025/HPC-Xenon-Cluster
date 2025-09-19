#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=8                # Total MPI tasks - 4 x 4
#SBATCH --ntasks-per-node=4       # balance tasks across nodes - 1 per gpu
#SBATCH --time=00:03:00           # Time limit hh:mm:ss
#SBATCH --nodes=2                 #
#SBATCH --nodelist=node1,node4    # nodes 1 and 2 are the only ones with hpcx for now

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

export UCX_LOG_LEVEL=info
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=ALL
export HPL_VERBOSE=1
export HPL_DEBUG=1


export UCX_NET_DEVICES=mlx5_0:1
export UCX_TLS=rc,sm,gdr,cuda_copy,cuda_ipc
export NCCL_IB_HCA=mlx5_0
export NCCL_IB_GID_INDEX=3
export NCCL_DEBUG=INFO


#testing
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun --mca plm_base_verbose 10 \
       --mca btl_base_verbose 100 \
       --mca oob_base_verbose 100 \
       --tag-output \
       ./xhpl-nvidia
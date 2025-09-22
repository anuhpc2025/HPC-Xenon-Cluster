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
source $HPCX_HOME/hpcx-init.sh
hpcx_load
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$HPCX_HOME/hcoll/lib:$HPCX_HOME/sharp/lib:$HPCX_HOME/ucc/lib:$HPCX_HOME/ncclnet_plugin/lib:$HPCX_HOME/nccl_rdma_sharp_plugin/lib:/usr/local/cuda-12.6/lib64:/usr/lib/x86_64-linux-gnu/nvshmem/12

export LD_LIBRARY_PATH=/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/omp:$LD_LIBRARY_PATH

# nvidia
export CUDA_VISIBLE_DEVICES=0,1,2,3
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1

export UCX_LOG_LEVEL=info
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=ALL
export HPL_VERBOSE=1
export HPL_DEBUG=1

export UCX_TLS=tcp,sm,self,cuda_copy,cuda_ipc
unset UCX_NET_DEVICES

export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_coll_ucc_enable=1

export NCCL_IB_HCA=mlx5_0
export NCCL_IB_GID_INDEX=3    # if fails try 0
export NCCL_P2P_LEVEL=SYS

#testing
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun --mca plm_base_verbose 10 \
       --mca btl_base_verbose 100 \
       --mca oob_base_verbose 100 \
       --tag-output \
       ./xhpl-nvidia
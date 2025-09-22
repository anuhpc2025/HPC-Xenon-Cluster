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
export OMP_NUM_THREADS=1
export CUDA_DEVICE_ORDER=PCI_BUS_ID
export CUDA_VISIBLE_DEVICES=2,3,0,1
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1
export LD_LIBRARY_PATH=/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/omp:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nccl:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/nvshmem/12:$LD_LIBRARY_PATH

export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_btl=^openib
export OMPI_MCA_opal_cuda_support=true
export OMPI_MCA_mpi_leave_pinned=1
export OMPI_MCA_rmaps_base_mapping_policy="ppr:4:node"
export OMPI_MCA_hwloc_base_binding_policy=core

export UCX_TLS=rc_x,sm,self,cuda_copy
export UCX_NET_DEVICES=mlx5_0:1
export UCX_RNDV_SCHEME=put_zcopy
export UCX_MEMTYPE_CACHE=y
export UCX_IB_PCI_RELAXED_ORDERING=off
export UCX_SOCKADDR_TLS_PRIORITY=rdmacm

# NCCL over IB/UCX
export NCCL_NET=UCX
export NCCL_IB_DISABLE=0
export NCCL_IB_HCA=mlx5_0
export NCCL_IB_GID_INDEX=0
export NCCL_SOCKET_IFNAME=^lo,docker*,veth*
# Enable PXN (so only NIC-close GPUs talk to NIC)
export NCCL_PXN_DISABLE=0
# Prefer large-message protocol
export NCCL_PROTO=SIMPLE
export NCCL_ALGO=Ring,Tree
# Raise GDR distance threshold if PXN can’t be enabled
export NCCL_IB_GDR_LEVEL=5
# Debug once
# export NCCL_DEBUG=INFO

#testing
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun ./xhpl-nvidia
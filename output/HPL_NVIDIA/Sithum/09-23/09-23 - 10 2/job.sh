#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=16                # Total MPI tasks - 4 x 4
#SBATCH --ntasks-per-node=4       # balance tasks across nodes - 1 per gpu
#SBATCH --time=00:03:00           # Time limit hh:mm:ss
#SBATCH --nodes=4                 #
#SBATCH --nodelist=node1,node2,node3,node4    # nodes 1 and 2 are the only ones with hpcx for now

# Load HPCX
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# Keep HPC-X libs first; then append CUDA and app libs
export LD_LIBRARY_PATH=$HPCX_HOME/ompi/lib:$HPCX_HOME/ucx/lib:\
$HPCX_HOME/hcoll/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:\
/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib:\
/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/omp:\
/usr/lib/x86_64-linux-gnu/nvshmem/12:\
$LD_LIBRARY_PATH

# GPU settings
export CUDA_DEVICE_ORDER=PCI_BUS_ID
export CUDA_VISIBLE_DEVICES=0,1,2,3
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1

# OMPI/UCX
export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_btl=^openib
export OMPI_MCA_opal_cuda_support=true
export OMPI_MCA_mpi_leave_pinned=1
export OMPI_MCA_rmaps_base_mapping_policy="ppr:4:node:pe=8"
export OMPI_MCA_hwloc_base_binding_policy=core
export OMPI_MCA_hwloc_base_report_bindings=1

# Enable HCOLL (SHARP offload if available)
export OMPI_MCA_coll_hcoll_enable=1
export UCX_IB_SHARP_ENABLE=y

# UCX for CUDA + IB
export UCX_TLS=rc_x,ud_x,sm,self,cuda_copy,gdr_copy,cuda_ipc
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_PCI_RELAXED_ORDERING=on
# Choose the close IB port(s); edit to your device names
export UCX_NET_DEVICES=mlx5_0:1

# Optional NCCL (if used via UCC or app)
export NCCL_DEBUG=WARN
export NCCL_IB_PCI_RELAXED_ORDERING=1

# Ulimits
ulimit -l unlimited
ulimit -n 65536

# Run
mpirun ./xhpl-nvidia
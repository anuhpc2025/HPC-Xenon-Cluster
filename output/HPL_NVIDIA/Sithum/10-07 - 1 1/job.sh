#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=16                # Total MPI tasks - 4 x 4
#SBATCH --ntasks-per-node=4       # balance tasks across nodes - 1 per gpu
#SBATCH --time=00:10:00           # Time limit hh:mm:ss
#SBATCH --nodes=4                 #
#SBATCH --nodelist=node1,node2,node3,node4    # nodes 1 and 2 are the only ones with hpcx for now

# Load HPCX
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$LD_LIBRARY_PATH
export PATH=$HPCX_HOME/ompi/bin:$PATH
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# NVIDIA env
export CUDA_VISIBLE_DEVICES=0,1,2,3
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1

# ---- NCCL choice: use system 2.27.7 ----
unset LD_PRELOAD
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

ENV_SCRIPT_DIR="$( cd -- "$( dirname -- "$( readlink -f "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )"

export LD_LIBRARY_PATH="${NCCL_PATH:-$ENV_SCRIPT_DIR/lib/nccl}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${NVSHMEM_PATH:-$ENV_SCRIPT_DIR/lib/nvshmem}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${NVPL_BLAS_PATH:-$ENV_SCRIPT_DIR/lib/nvpl_blas}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${NVPL_LAPACK_PATH:-$ENV_SCRIPT_DIR/lib/nvpl_lapack}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${NVPL_SPARSE_PATH:-$ENV_SCRIPT_DIR/lib/nvpl_sparse}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${OMP_PATH:-$ENV_SCRIPT_DIR/lib/omp}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

export OMPI_MCA_coll_hcoll_enable=0

# OMPI / UCX tuning
export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_btl=^openib
export OMPI_MCA_opal_cuda_support=true
export OMPI_MCA_mpi_leave_pinned=1
export OMPI_MCA_rmaps_base_mapping_policy="ppr:2:numa:pe=8"
export OMPI_MCA_hwloc_base_binding_policy=core

export UCX_TLS=rc_x,sm,self,cuda_copy,gdr_copy,cuda_ipc
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_PCI_RELAXED_ORDERING=on

# Ulimits
ulimit -l unlimited
ulimit -n 65536

# Run
mpirun ./xhpl-nvidia
#!/bin/bash
#SBATCH --job-name=24-09-02       # Job name
#SBATCH --ntasks=4                # Total MPI tasks - 4 x 4
#SBATCH --ntasks-per-node=4       # balance tasks across nodes - 1 per gpu
#SBATCH --time=00:10:00           # Time limit hh:mm:ss
#SBATCH --nodes=1                 #
#SBATCH --nodelist=node1    # nodes 1 and 2 are the only ones with hpcx for now
#SBATCH --gpus-per-task=1

unset LD_LIBRARY_PATH
unset PATH
unset OMPI_MCA
unset UCX_TLS

# Load HPCX
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# NVIDIA env
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1
export CUDA_VISIBLE_DEVICES=$(echo $SLURM_LOCALID)

ENV_SCRIPT_DIR="/home/hpc/mxp/nvidia_hpc_benchmarks_openmpi-linux-x86_64-25.09.06-archive/cuda13"

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
export OMPI_MCA_btl=^openib # Explicitly disable OpenIB BTL, force UCX usage
export OMPI_MCA_opal_cuda_support=true
export OMPI_MCA_mpi_leave_pinned=1

export UCX_TLS=rc_x,sm,self,cuda_copy,gdr_copy,cuda_ipc
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_PCI_RELAXED_ORDERING=on

# Ulimits
ulimit -l unlimited
ulimit -n 65536

# Run
mpirun ./xhpl_mxp-nvidia \
  --nprow 2 \
  --npcol 2 \
  --nporder row \
  --sloppy-type 2 \
  --n 90000 \
  --nb 384 \
  --preset-gemm-kernel 0
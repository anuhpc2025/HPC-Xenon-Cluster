#!/bin/bash
#SBATCH --job-name=24-09-02       # Job name
#SBATCH --ntasks=4                # Total MPI tasks - 4 x 4
#SBATCH --ntasks-per-node=4       # balance tasks across nodes - 1 per gpu
#SBATCH --time=00:10:00           # Time limit hh:mm:ss
#SBATCH --nodes=1                 #
#SBATCH --nodelist=node1    # nodes 1 and 2 are the only ones with hpcx for now
#SBATCH --gpus-per-task=1

# Load HPC-X (adjust path to match your install)
source /home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64/hpcx-init.sh
hpcx_load

# UCX & OpenMPI environment
export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_btl=self,vader
export UCX_TLS=rc,sm,self,cuda_copy,gdr_copy
export UCX_POSIX_USE_PROC_LINK=n      # disable CMA
export UCX_MEMTYPE_CACHE=n
export UCX_WARN_UNUSED_ENV_VARS=n

# Network device (if you want to use IB intra-node as well)
export UCX_NET_DEVICES=mlx5_0:1

# For GPU awareness and pinned mem performance
export OMPI_MCA_opal_cuda_support=true
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_GPU_DIRECT_RDMA=yes
export UCX_GPU_COPY_MODE=cuda_copy


export CUDA_VISIBLE_DEVICES=$(echo $SLURM_LOCALID)

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
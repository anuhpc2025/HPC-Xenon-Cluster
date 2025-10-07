#!/bin/bash
#SBATCH --job-name=24-09-02       # Job name
#SBATCH --ntasks=4                # Total MPI tasks - 4 x 4
#SBATCH --ntasks-per-node=4       # balance tasks across nodes - 1 per gpu
#SBATCH --time=00:10:00           # Time limit hh:mm:ss
#SBATCH --nodes=1                 #
#SBATCH --nodelist=node1    # nodes 1 and 2 are the only ones with hpcx for now
#SBATCH --gpus-per-task=1

# Load HPCX
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$LD_LIBRARY_PATH
export PATH=$HPCX_HOME/ompi/bin:$PATH
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# NVIDIA env
#export CUDA_VISIBLE_DEVICES=0,1,2,3
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1

# ---- NCCL choice: use system 2.27.7 ----
unset LD_PRELOAD
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

# Optional: add CUDA & other NVIDIA libs, but *not* /opt/.../lib/nccl
export LD_LIBRARY_PATH=/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/omp:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/nvshmem/12:$LD_LIBRARY_PATH

# UCX / OpenMPI CPU↔︎GPU intra-node setup
export OMPI_MCA_btl=^openib
export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_opal_cuda_support=true

# Disable UCX IB verbs, keep IPC & CUDA copies
export UCX_TLS=sm,self,cuda_copy,gdr_copy,cuda_ipc
export UCX_NET_DEVICES=all
export UCX_CMA_ENABLE=n
export OMPI_MCA_btl_smcuda_use_knem=0
export UCX_IB_GPU_DIRECT_RDMA=n  # avoid unneeded verbs path

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
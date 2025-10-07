#!/bin/bash
#SBATCH --job-name=24-09-02       # Job name
#SBATCH --ntasks=1                # Total MPI tasks - 4 x 4
#SBATCH --ntasks-per-node=1       # balance tasks across nodes - 1 per gpu
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

# OMPI / UCX tuning
export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_btl=^openib
export OMPI_MCA_opal_cuda_support=true
export OMPI_MCA_mpi_leave_pinned=1
#export OMPI_MCA_rmaps_base_mapping_policy="ppr:2:numa:pe=8"
#export OMPI_MCA_hwloc_base_binding_policy=core

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
  --nprow 1 \
  --npcol 1 \
  --nporder row \
  --sloppy-type 2 \
  --n 70000 \
  --nb 256 \
  --preset-gemm-kernel 0
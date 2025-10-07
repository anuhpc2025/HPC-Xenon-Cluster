#!/bin/bash
#SBATCH --job-name=24-09-02
#SBATCH --ntasks=4
#SBATCH --ntasks-per-node=4
#SBATCH --time=00:10:00
#SBATCH --nodes=1
#SBATCH --nodelist=node1
#SBATCH --gpus-per-task=1

# --- Load HPC-X -----------------------------------------------------------
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
export PATH=$HPCX_HOME/ompi/bin:$PATH
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$LD_LIBRARY_PATH
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# --- NVIDIA / CUDA environment -------------------------------------------
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1
unset LD_PRELOAD

# make sure HPCX UCX is first, then GPU/CUDA libs, then system libs
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda-12.6/lib64
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/omp
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu/nvshmem/12
# put /usr/lib last, never first
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu

# --- OMPI / UCX tuning ----------------------------------------------------
export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_btl=^openib
export OMPI_MCA_opal_cuda_support=true
export OMPI_MCA_mpi_leave_pinned=1

# CUDA-aware UCX transports; disable CMA explicitly
export UCX_TLS=rc_x,sm,self,cuda_copy,gdr_copy,cuda_ipc
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_PCI_RELAXED_ORDERING=on

# --- Misc ---------------------------------------------------------------
export CUDA_VISIBLE_DEVICES=$SLURM_LOCALID
ulimit -l unlimited
ulimit -n 65536

# --- Optional sanity check (comment out later) ---------------------------
echo ">>> UCX libraries in use:"
ldd $(which mpirun) | grep ucx || true

# --- Run benchmark -------------------------------------------------------
mpirun --mca pml ucx --mca btl ^openib --mca osc ucx \
  -x LD_LIBRARY_PATH -x PATH -x UCX_TLS \
  -x HPL_USE_GPU -x HPL_CUDA_MODE -x CUDA_VISIBLE_DEVICES \
  ./xhpl_mxp-nvidia \
    --nprow 2 \
    --npcol 2 \
    --nporder row \
    --sloppy-type 2 \
    --n 90000 \
    --nb 384 \
    --preset-gemm-kernel 0
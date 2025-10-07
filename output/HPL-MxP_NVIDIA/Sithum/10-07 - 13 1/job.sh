#!/bin/bash
#SBATCH --job-name=24-09-02       # Job name
#SBATCH --ntasks=4                # Total MPI tasks - 4 x 4
#SBATCH --ntasks-per-node=4       # balance tasks across nodes - 1 per gpu
#SBATCH --time=00:10:00           # Time limit hh:mm:ss
#SBATCH --nodes=1                 #
#SBATCH --nodelist=node1    # nodes 1 and 2 are the only ones with hpcx for now
#SBATCH --gpus-per-task=1

# --- HPCX setup ---
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source $HPCX_HOME/hpcx-init.sh
hpcx_load
export PATH=$HPCX_HOME/ompi/bin:$PATH
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:/usr/local/cuda-13.0/targets/x86_64-linux/lib:$LD_LIBRARY_PATH

# --- Verify we're using the right UCX ---
ldd $(which mpirun) | grep ucx || echo "⚠️ No UCX linked into mpirun"

# --- UCX / MPI tuning ---
export UCX_TLS=shm,self,cuda_copy,gdr_copy,cuda_ipc
export UCX_POSIX_USE_PROC_PATH=no
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_IB_PCI_RELAXED_ORDERING=on
export OMPI_MCA_btl_vader_single_copy_mechanism=none

# --- CUDA / mapping ---
export CUDA_VISIBLE_DEVICES=$(echo $SLURM_LOCALID)
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1

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
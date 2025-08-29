#!/bin/bash
#SBATCH --job-name=hpl-12gpu
#SBATCH --nodes=3
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=4
#SBATCH --gpus-per-node=4        # or: --gres=gpu:4 (cluster dependent)
#SBATCH --time=01:00:00
#SBATCH --exclusive
#SBATCH --nodelist=node1,node2,node3

# Load your MPI/CUDA stacks as appropriate for your site
# module load cuda/12.6 openmpi/4.1.6

export PATH=/opt/ompi-4.1.6/bin:$PATH
export LD_LIBRARY_PATH=/opt/ompi-4.1.6/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:\
/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nvshmem:\
/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nccl:\
/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib:\
$LD_LIBRARY_PATH

# Enable GPU path (if your xhpl build uses these)
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1

# CUDA-aware MPI/UCX (tune per site)
export OMPI_MCA_pml=ucx
export OMPI_MCA_btl=^openib
export OMPI_MCA_opal_cuda_support=true
export UCX_TLS=rc_x,sm,cuda_copy,gdr_copy
export UCX_MEMTYPE_CACHE=n

ulimit -l unlimited
ulimit -n 65536

# Do NOT set CUDA_VISIBLE_DEVICES globally
unset CUDA_VISIBLE_DEVICES

# 12 ranks total; 1 GPU per rank; bind each rank to the nearest GPU
mpirun -np ${SLURM_NTASKS} \
  --map-by ppr:4:node:pe=${SLURM_CPUS_PER_TASK} --bind-to core \
  -x OMPI_MCA_pml=ucx -x OMPI_MCA_opal_cuda_support=true \
  bash -lc 'export CUDA_VISIBLE_DEVICES=${OMPI_COMM_WORLD_LOCAL_RANK}; \
            exec ./xhpl-nvidia'
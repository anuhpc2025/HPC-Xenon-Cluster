#!/bin/bash
#SBATCH --job-name=hpl-test
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=4
#SBATCH --gpus-per-node=4          # or: --gres=gpu:4 (cluster dependent)
#SBATCH --time=01:00:00
#SBATCH --exclusive

# Load your MPI/CUDA stacks as appropriate for your site
# module load cuda/12.6 openmpi/4.1.6

export PATH=/opt/ompi-4.1.6/bin:$PATH
export LD_LIBRARY_PATH=/opt/ompi-4.1.6/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:\
/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nvshmem:\
/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nccl:\
/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib:\
$LD_LIBRARY_PATH

# Optional UCX/CUDA-aware MPI knobs (tune for your fabric)
export OMPI_MCA_pml=ucx
export OMPI_MCA_btl=^openib
export OMPI_MCA_opal_cuda_support=true
export UCX_TLS=rc_x,sm,cuda_copy,gdr_copy
export UCX_MEMTYPE_CACHE=n

ulimit -l unlimited
ulimit -n 65536

# inside the same allocation (after the SBATCH header above)
# Remove any global CUDA_VISIBLE_DEVICES
unset CUDA_VISIBLE_DEVICES

mpirun -np ${SLURM_NTASKS} \
  --map-by ppr:4:node:pe=${SLURM_CPUS_PER_TASK} --bind-to core \
  -x OMPI_MCA_pml=ucx -x OMPI_MCA_opal_cuda_support=true \
  bash -lc 'export CUDA_VISIBLE_DEVICES=${OMPI_COMM_WORLD_LOCAL_RANK}; \
            exec ./xhpl-nvidia'
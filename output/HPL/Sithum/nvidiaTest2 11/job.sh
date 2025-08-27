#!/bin/bash
#SBATCH --job-name=hpl-test
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --gpus-per-task=1
#SBATCH --cpus-per-task=16
#SBATCH --time=01:00:00
#SBATCH --output=hpl-%j.out
#SBATCH --error=hpl-%j.err
#SBATCH --nodelist=node1
#SBATCH --exclusive

# Load MPI module (adjust for your system)
module load cuda/12.x
module load openmpi
export LD_LIBRARY_PATH=/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nvshmem/:$LD_LIBRARY_PATH

#testing
ulimit -l unlimited
ulimit -n 65536

export NVSHMEM_DISABLE_CUDA_VMM=1
export NVSHMEM_SYMMETRIC_SIZE=1G

export NVSHMEM_DEBUG=INFO

export NCCL_DEBUG=INFO

# Run the MPI program
srun --mpi=pmix --gpu-bind=single:1 --cpu-bind=cores ./xhpl
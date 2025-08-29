#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=8        # CPU cores per MPI task
#SBATCH --gres=gpu:4,ib:1
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --nodelist=node1,node2

# Load MPI module (adjust for your system)
# module load openmpi
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1

export PATH=/opt/ompi-4.1.6/bin:$PATH
export LD_LIBRARY_PATH=/opt/ompi-4.1.6/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nvshmem:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nccl:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib:$LD_LIBRARY_PATH

#testing
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun ./xhpl-nvidia
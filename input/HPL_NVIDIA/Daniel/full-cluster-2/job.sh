#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=16                # Total MPI tasks - 4 x 4
#SBATCH --cpus-per-task=4        # CPU cores per MPI task
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --nodes=4
#SBATCH --nodelist=node1,node2,node3,node4

# Load MPI module (adjust for your system)
# module load openmpi
export CUDA_VISIBLE_DEVICES=0,1,2,3
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
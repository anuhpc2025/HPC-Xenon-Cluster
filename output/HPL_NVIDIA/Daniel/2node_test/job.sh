#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=8                # Total MPI tasks - 4 x 4
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --nodes=2
#SBATCH --nodelist=node1,node2

# Load MPI module (adjust for your system)
# module load openmpi
export CUDA_VISIBLE_DEVICES=0,1,2,3
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1

#testing
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun ./xhpl-nvidia
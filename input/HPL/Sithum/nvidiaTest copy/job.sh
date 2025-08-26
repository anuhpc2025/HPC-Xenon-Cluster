#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --nodes=1                 # Number of nodes
#SBATCH --ntasks=4                # Total MPI tasks
#SBATCH --ntasks-per-node=4       # MPI tasks per node
#SBATCH --cpus-per-task=16        # CPU cores per MPI task
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --output=hpl-%j.out       # Standard output file
#SBATCH --error=hpl-%j.err        # Standard error file

# Load MPI module (adjust for your system)
# module load openmpi
export LD_LIBRARY_PATH=/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nvshmem/:$LD_LIBRARY_PATH

#testing
export NVSHMEM_BOOTSTRAP_PMI=pmix
export NVSHMEM_USE_IBGDA=0
export NVSHMEM_USE_IBRC=0


# Run the MPI program
mpirun ./xhpl
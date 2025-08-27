#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=1                # Total MPI tasks
#SBATCH --cpus-per-task=4         # CPU cores per MPI task
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --nodelist=node1

# Load MPI module (adjust for your system)
# module load openmpi
export LD_LIBRARY_PATH=/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nvshmem/:$LD_LIBRARY_PATH

#testing
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun ./xhpl
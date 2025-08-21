#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --nodes=4                 # Number of nodes
#SBATCH --ntasks=64               # Total MPI tasks
#SBATCH --ntasks-per-node=16      # MPI tasks per node
#SBATCH --cpus-per-task=1         # CPU cores per MPI task
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --output=hpl-%j.out       # Standard output file
#SBATCH --error=hpl-%j.err        # Standard error file

# Load MPI module (adjust for your system)
module load mpi

# Run the MPI program
salloc -N 2 -n 4 --ntasks-per-node=2
mpirun ./xhpl

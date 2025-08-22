#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --nodes=1                 # Number of nodes
#SBATCH --ntasks=2                # Total MPI tasks
#SBATCH --ntasks-per-node=4       # MPI tasks per node
#SBATCH --cpus-per-task=16        # CPU cores per MPI task
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --output=hpl-%j.out       # Standard output file
#SBATCH --error=hpl-%j.err        # Standard error file

# Load MPI module (adjust for your system)
module load mpi

# Run the MPI program
mpirun ./xhpl
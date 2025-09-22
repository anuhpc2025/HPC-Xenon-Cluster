#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=4                # Total MPI tasks
#SBATCH --cpus-per-task=16        # CPU cores per MPI task
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --nodelist=node1
#SBATCH --gpus-per-task=1

# Run the MPI program
mpirun ./xhpl-nvidia
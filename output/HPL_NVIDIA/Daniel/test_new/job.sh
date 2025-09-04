#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=16                # Total MPI tasks - 4 x 4
#SBATCH --ntasks-per-node=4       # balance tasks across nodes - 1 per gpu
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --nodes=2                 #
#SBATCH --nodelist=node1,node2    # nodes 1 and 2 are the only ones with hpcx for now

# Load hpcx module


# module load openmpi

#testing
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun ./xhpl-nvidia
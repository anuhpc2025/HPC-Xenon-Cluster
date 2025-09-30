#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=32              # Total MPI tasks
#SBATCH --ntasks-per-node=32       # MPI tasks per node
#SBATCH --cpus-per-task=1         # CPU cores per MPI task
#SBATCH --time=12:00:00           # Time limit hh:mm:ss
#SBATCH --output=hpl-%j.out       # Standard output file
#SBATCH --error=hpl-%j.err        # Standard error file
#SBATCH --nodes=1                 # Number of nodes
#SBATCH --nodelist=node1    # nodes 1 and 2 are the only ones with hpcx for now

# Load MPI module (adjust for your system)
# module load openmpi

# Load HPCX
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$LD_LIBRARY_PATH
export PATH=$HPCX_HOME/ompi/bin:$PATH
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# Run the MPI program
mpirun ./xhpl
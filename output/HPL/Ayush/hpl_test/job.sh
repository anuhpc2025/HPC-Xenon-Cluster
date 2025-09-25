#!/bin/bash
#SBATCH --job-name=hpl-cpu
#SBATCH --nodes=1
#SBATCH --ntasks=9                 # matches P×Q in HPL.dat (3×3)
#SBATCH --ntasks-per-node=9
#SBATCH --cpus-per-task=3          # OpenMP threads per rank
#SBATCH --time=01:00:00
#SBATCH --output=hpl-%j.out
#SBATCH --error=hpl-%j.err

set -euo pipefail

# Use HPC-X MPI already installed
export PATH="/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64/ompi/bin:$PATH"

# If your xhpl needs OpenBLAS/MKL in $HOME/.local/lib, expose it (harmless if not needed)
export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"

# OpenMP threads = cpus-per-task
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"

# Bind ranks cleanly to cores
MPI_BIND="--bind-to core --map-by socket:PE=${SLURM_CPUS_PER_TASK:-1}"

# Go where HPL.dat is
cd "$(dirname "$0")"
echo "PWD=$(pwd)"
echo "mpirun=$(which mpirun)"
echo "Binary=/home/hpc/xhpl"
echo "NTASKS=${SLURM_NTASKS:-unset}  OMP_NUM_THREADS=$OMP_NUM_THREADS"

mpirun ${MPI_BIND} -np "${SLURM_NTASKS:-9}" /home/hpc/xhpl

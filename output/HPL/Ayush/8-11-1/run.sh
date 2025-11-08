#!/bin/bash
#SBATCH --job-name=hpl-test
#SBATCH --nodes=4
#SBATCH --ntasks=64
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00

source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# HPC-X first
export LD_LIBRARY_PATH=${HPCX_HOME}/ucx/lib:${HPCX_HOME}/ompi/lib:${LD_LIBRARY_PATH}
export PATH=${HPCX_HOME}/ompi/bin:${PATH}

# AOCL
export AOCLROOT=/opt/AMD/aocl-5.1.0/5.1.0/gcc
export LD_LIBRARY_PATH=${AOCLROOT}/lib:${LD_LIBRARY_PATH}

# OpenMP
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=true
export OMP_PLACES=cores
export BLIS_ENABLE_OPENMP=1
export BLIS_CPU_EXT=ZEN3
export BLIS_DYNAMIC_SCHED=0

# UCX tuning
export UCX_TLS=rc_x,sm,self
export UCX_ADAPTIVE_PROGRESS=n

ulimit -l unlimited
ulimit -n 65536

mpirun \
  --map-by ppr:16:node:PE=1 --rank-by core --bind-to core --report-bindings \
  --mca pml ucx --mca osc ucx \
  -x LD_LIBRARY_PATH -x PATH \
  -x AOCLROOT -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x BLIS_ENABLE_OPENMP -x BLIS_CPU_EXT -x BLIS_DYNAMIC_SCHED \
  -x UCX_TLS -x UCX_ADAPTIVE_PROGRESS \
  /home/hpc/hpl-2.3/testing/xhpl

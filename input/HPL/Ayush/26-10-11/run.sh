#!/bin/bash
#SBATCH --job-name=hpl-test
#SBATCH --ntasks=128
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --nodes=4
#SBATCH --nodelist=node1,node2,node3,node4

# --- HPC-X only (don’t rely on ~/.bashrc) ---
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source "${HPCX_HOME}/hpcx-init.sh"
hpcx_load

# --- AOCL BLIS ---
export AOCLROOT=/opt/AMD/aocl-5.1.0/5.1.0/gcc

# OpenMP/BLIS (CPU HPL)
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=true
export OMP_PLACES=cores
export BLIS_ENABLE_OPENMP=1
export BLIS_CPU_EXT=ZEN3
export BLIS_DYNAMIC_SCHED=0

# --- UCX transport (IB) ---
export UCX_NET_DEVICES=mlx5_0:1
export UCX_TLS=rc_x,sm,self
unset UCX_IB_GPU_DIRECT_RDMA
unset UCX_IB_PCI_RELAXED_ORDERING

# --- Clean library path: keep HPC-X first; remove system UCX/NCCL/CUDA ---
CLEAN_LD=$(printf "%s" "${LD_LIBRARY_PATH}" \
  | tr ':' '\n' \
  | grep -vE '^/usr/lib/x86_64-linux-gnu($|/)' \
  | grep -vE '^/usr/local/cuda' \
  | grep -vE '/nccl' \
  | paste -sd:)
export LD_LIBRARY_PATH="${HPCX_HOME}/ucx/lib:${HPCX_HOME}/ompi/lib:${AOCLROOT}/lib:${CLEAN_LD}"

# No LD_PRELOAD; no /usr/lib pre-pend
ulimit -l unlimited
ulimit -n 65536

# --- Force remote prefix to HPC-X tree ---
export OPAL_PREFIX="${HPCX_HOME}/ompi"

# --- Run ---
"${HPCX_HOME}/ompi/bin/mpirun" \
  --prefix "${HPCX_HOME}/ompi" \
  --map-by ppr:32:node:PE=1 --rank-by core --bind-to core --report-bindings \
  -x LD_LIBRARY_PATH -x PATH -x OPAL_PREFIX \
  -x AOCLROOT -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x BLIS_ENABLE_OPENMP -x BLIS_CPU_EXT -x BLIS_DYNAMIC_SCHED \
  -x UCX_TLS -x UCX_NET_DEVICES \
  ./xhpl

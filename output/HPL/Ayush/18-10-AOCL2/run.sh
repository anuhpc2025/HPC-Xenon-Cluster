#!/bin/bash
#SBATCH --job-name=hpl-test             # Job name
#SBATCH --ntasks=128                    # Total MPI tasks
#SBATCH --ntasks-per-node=32            # MPI tasks per node
#SBATCH --cpus-per-task=1               # CPU cores per MPI task
#SBATCH --time=10:00:00                 # Time limit hh:mm:ss
#SBATCH --nodes=4                       # Number of nodes
#SBATCH --nodelist=node1,node2,node3,node4

set -euo pipefail

########################################
# Paths / env
########################################
# HPL location (HPL.dat should be here)
export HPL_DIR="$HOME/hpl-2.3"
export HPL_BIN="$HPL_DIR/testing/xhpl"

# HPC-X
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$LD_LIBRARY_PATH
export PATH=$HPCX_HOME/ompi/bin:$PATH
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# AOCL BLIS (threaded libs available; we’ll keep OMP=1 for pure-MPI)
export AOCL_DIR=$HOME/aocl
export AOCL_BLIS=$AOCL_DIR/5.1.0/gcc
export LD_LIBRARY_PATH=$AOCL_BLIS/lib:$LD_LIBRARY_PATH

# (Optional) CUDA/NVIDIA extras are harmless for CPU HPL; keep if you like
unset LD_PRELOAD
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/omp:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/nvshmem/12:$LD_LIBRARY_PATH

# UCX knobs (HPC-X + IB)
export UCX_TLS=rc_x,sm,self
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy

# OpenMP — keep BLIS single-threaded for pure-MPI
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=close
export OMP_PLACES=cores

# Ulimits
ulimit -l unlimited
ulimit -n 65536

########################################
# Info + quick ldd
########################################
echo "== Nodes:          $SLURM_NODELIST"
echo "== Tasks:          $SLURM_NTASKS (per node: $SLURM_NTASKS_PER_NODE)"
echo "== HPL dir/bin:    $HPL_DIR / $HPL_BIN"
echo "== UCX_TLS:        $UCX_TLS"
echo "== LD_LIBRARY_PATH:"
echo "$LD_LIBRARY_PATH" | tr ':' '\n' | sed 's/^/   /'
echo
echo "== ldd on xhpl (look for blis/openblas/mkl):"
ldd "$HPL_BIN" | egrep 'blis|openblas|mkl' || true
echo

########################################
# Run HPL (mpirun under Slurm allocation)
########################################
cd "$HPL_DIR"

# Map exactly 32 ranks per node, bind ranks to cores (1 core per rank),
# export env to all ranks, and use UCX PML.
mpirun -np "$SLURM_NTASKS" \
  --map-by ppr:${SLURM_NTASKS_PER_NODE}:node:pe=${SLURM_CPUS_PER_TASK} \
  --bind-to core \
  --report-bindings \
  --mca pml ucx \
  -x LD_LIBRARY_PATH \
  -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x UCX_TLS -x UCX_IB_GPU_DIRECT_RDMA -x UCX_MEMTYPE_CACHE -x UCX_RNDV_SCHEME \
  -x AOCL_DIR -x AOCL_BLIS \
  ./testing/xhpl

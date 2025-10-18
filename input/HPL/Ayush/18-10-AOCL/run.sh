#!/bin/bash
#SBATCH --job-name=hpl-aocl
#SBATCH --nodes=4
#SBATCH --nodelist=node1,node2,node3,node4
#SBATCH --ntasks-per-node=32          # 32 MPI ranks per node
#SBATCH --cpus-per-task=1             # pure-MPI; BLIS threads = 1
#SBATCH --time=10:00:00
#SBATCH --output=hpl_out.%j

########## User-adjustable paths ##########
# HPL build dir and binary (from your build)
export HPL_DIR="$HOME/hpl-2.3"
export HPL_BIN="$HPL_DIR/testing/xhpl"   # HPL.dat should be in $HPL_DIR

# HPC-X root (you already have this)
export HPCX_HOME="/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64"

# AOCL/BLIS path (you copied this to all nodes under $HOME)
export AOCL_BLIS="$HOME/aocl/5.1.0/gcc"

########## Environment: MPI / UCX / BLIS ##########
# Load HPC-X (Open MPI + UCX) into env
source "$HPCX_HOME/hpcx-init.sh"
hpcx_load

# Make sure HPC-X binaries and libs are preferred
export PATH="$HPCX_HOME/ompi/bin:$PATH"
export LD_LIBRARY_PATH="$HPCX_HOME/ompi/lib:$HPCX_HOME/ucx/lib:$LD_LIBRARY_PATH"

# Add AOCL/BLIS to runtime path
export LD_LIBRARY_PATH="$AOCL_BLIS/lib:$LD_LIBRARY_PATH"

# UCX knobs for IB (tweak to taste)
export UCX_TLS="rc_x,sm,self"
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy

# Pure-MPI: keep BLIS single-threaded
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=close
export OMP_PLACES=cores

# Lockable memory / fds
ulimit -l unlimited
ulimit -n 65536

########## Sanity checks (helpful in logs) ##########
echo "== Nodes:          $SLURM_NODELIST"
echo "== Ranks/node:     $SLURM_NTASKS_PER_NODE"
echo "== Total ranks:    $SLURM_NTASKS"
echo "== HPL dir:        $HPL_DIR"
echo "== HPL binary:     $HPL_BIN"
echo "== Using BLIS at:  $AOCL_BLIS"
echo "== UCX_TLS:        $UCX_TLS"
echo
echo "== ldd on xhpl (expect libblis*, not openblas/mkl):"
srun -N1 -n1 bash -lc "ldd '$HPL_BIN' | egrep 'blis|openblas|mkl|flame' || true"
echo

########## Run ##########
# HPL reads HPL.dat from CWD; run inside the HPL dir.
cd "$HPL_DIR"

# Launch with Slurm PMI via PMIx (HPC-X uses pmix_v4)
srun --mpi=pmix_v4 "$HPL_BIN"

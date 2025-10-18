#!/bin/bash
#SBATCH --job-name=hpl-test
#SBATCH --nodes=4
#SBATCH --nodelist=node1,node2,node3,node4
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --time=10:00:00
#SBATCH --output=hpl_out.%j

# Be strict on errors, but don't use -u (nounset) because hpcx-init.sh reads unset vars.
set -eo pipefail

########################################
# Paths
########################################
# HPL location (HPL.dat should be in this dir)
export HPL_DIR="$HOME/hpl-2.3"
export HPL_BIN="$HPL_DIR/testing/xhpl"

# HPC-X root
export HPCX_HOME="/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64"
# Avoid "unbound variable" inside hpcx-init.sh
export HPCX_ENABLE_NCCLNET_PLUGIN=0

########################################
# Load MPI stack (HPC-X Open MPI + UCX)
########################################
source "$HPCX_HOME/hpcx-init.sh"
hpcx_load

# Prefer HPC-X in PATH/LD_LIBRARY_PATH
export PATH="$HPCX_HOME/ompi/bin:$PATH"
export LD_LIBRARY_PATH="$HPCX_HOME/ompi/lib:$HPCX_HOME/ucx/lib:$LD_LIBRARY_PATH"

########################################
# BLAS (AOCL BLIS)
########################################
export AOCL_BLIS="$HOME/aocl/5.1.0/gcc"
export LD_LIBRARY_PATH="$AOCL_BLIS/lib:$LD_LIBRARY_PATH"

########################################
# UCX tuning (IB)
########################################
export UCX_TLS="rc_x,sm,self"
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy

########################################
# OpenMP (pure-MPI)
########################################
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=close
export OMP_PLACES=cores

# Ulimits
ulimit -l unlimited
ulimit -n 65536

########################################
# Info
########################################
echo "== Nodes:          $SLURM_NODELIST"
echo "== Tasks total:    $SLURM_NTASKS (per node: $SLURM_NTASKS_PER_NODE)"
echo "== HPL dir/bin:    $HPL_DIR / $HPL_BIN"
echo "== UCX_TLS:        $UCX_TLS"
echo

########################################
# Conditional (re)build to force BLIS
########################################
need_rebuild=0
if [[ ! -x "$HPL_BIN" ]]; then
  echo "== HPL binary missing; will build."
  need_rebuild=1
else
  # If linked to OpenBLAS or not linked to BLIS, rebuild
  if readelf -d "$HPL_BIN" 2>/dev/null | grep -qi 'NEEDED.*openblas'; then need_rebuild=1; fi
  if ! readelf -d "$HPL_BIN" 2>/dev/null | grep -qi 'NEEDED.*blis'; then need_rebuild=1; fi
fi

if (( need_rebuild )); then
  echo "== Rebuilding HPL with AOCL BLIS (overriding BLASLIBS)..."
  make -C "$HPL_DIR" clean
  make -C "$HPL_DIR" -j "$(nproc)" \
    BLASLIBS="-L$AOCL_BLIS/lib -lblis-mt -lpthread -lm" \
    LIBS=""
fi

echo
echo "== Link dependencies on submit node (expect **blis**, NOT openblas/mkl):"
readelf -d "$HPL_BIN" | egrep -i 'NEEDED.*(blis|openblas|mkl)' || true
echo

echo "== ldd on submit node:"
ldd "$HPL_BIN" | egrep -i 'blis|openblas|mkl' || true
echo

echo "== Sanity on all nodes (readelf NEEDED):"
srun -N "$SLURM_NNODES" -l bash -lc "readelf -d '$HPL_BIN' 2>/dev/null | egrep -i \"NEEDED.*(blis|openblas|mkl)\" || true"
echo

########################################
# Run (mpirun inside the Slurm allocation)
########################################
cd "$HPL_DIR"

mpirun -np "$SLURM_NTASKS" \
  --map-by ppr:${SLURM_NTASKS_PER_NODE}:node:pe=${SLURM_CPUS_PER_TASK} \
  --bind-to core \
  --report-bindings \
  --mca pml ucx \
  -x LD_LIBRARY_PATH \
  -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x UCX_TLS -x UCX_MEMTYPE_CACHE -x UCX_RNDV_SCHEME \
  -x AOCL_BLIS \
  "$HPL_BIN"

#!/bin/bash
#SBATCH --job-name=hpl-test
#SBATCH --nodes=4
#SBATCH --ntasks=64
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00

# ---- 1) load HPC-X ----
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# ---- 2) add the SYSTEM libs FIRST (so everything needed is there) ----
# this is the line you said makes the hang go away, so keep it:
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}

# ---- 3) NOW re-prepend HPC-X UCX + OMPI so UCX 1.19 wins ----
export LD_LIBRARY_PATH=${HPCX_HOME}/ucx/lib:${HPCX_HOME}/ompi/lib:${LD_LIBRARY_PATH}
export PATH=${HPCX_HOME}/ompi/bin:${PATH}

# ---- 4) AOCL ----
export AOCLROOT=/opt/AMD/aocl-5.1.0/5.1.0/gcc
export LD_LIBRARY_PATH=${AOCLROOT}/lib:${LD_LIBRARY_PATH}

# ---- 5) OpenMP / BLIS ----
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=true
export OMP_PLACES=cores
export BLIS_ENABLE_OPENMP=1
export BLIS_CPU_EXT=ZEN3
export BLIS_DYNAMIC_SCHED=0

# ---- 7) UCX tuning / hang workaround from HPC-X known issues ----
export UCX_TLS=rc_x,sm,self
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_PCI_RELAXED_ORDERING=on
# HPC-X says some hangs are solved by disabling adaptive progress: :contentReference[oaicite:3]{index=3}
export UCX_ADAPTIVE_PROGRESS=n

# ---- 8) make REALLY sure every rank uses this UCX (belt + suspenders) ----
export LD_PRELOAD=${HPCX_HOME}/ucx/lib/libucp.so.0:${HPCX_HOME}/ucx/lib/libuct.so.0:${HPCX_HOME}/ucx/lib/libucs.so.0

ulimit -l unlimited
ulimit -n 65536

mpirun \
  --map-by ppr:16:node:PE=1 --rank-by core --bind-to core --report-bindings \
  --mca pml ucx --mca osc ucx \
  -x LD_LIBRARY_PATH -x PATH -x LD_PRELOAD \
  -x AOCLROOT -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x BLIS_ENABLE_OPENMP -x BLIS_CPU_EXT -x BLIS_DYNAMIC_SCHED \
  -x UCX_TLS -x UCX_ADAPTIVE_PROGRESS -x UCX_IB_GPU_DIRECT_RDMA \
  -x UCX_MEMTYPE_CACHE -x UCX_RNDV_SCHEME -x UCX_IB_PCI_RELAXED_ORDERING \
  ./xhpl

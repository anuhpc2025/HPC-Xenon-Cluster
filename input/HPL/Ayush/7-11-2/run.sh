#!/bin/bash
#SBATCH --job-name=hpl-test
#SBATCH --nodes=4
#SBATCH --ntasks=64               # 16 per node × 4 nodes
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00

# 1) Load HPCX first
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# 2) Make sure HPCX UCX + OMPI are FIRST on the path
export LD_LIBRARY_PATH=${HPCX_HOME}/ucx/lib:${HPCX_HOME}/ompi/lib:${LD_LIBRARY_PATH}
export PATH=${HPCX_HOME}/ompi/bin:${PATH}

# 3) AOCL BLIS (add after HPCX)
export AOCLROOT=/opt/AMD/aocl-5.1.0/5.1.0/gcc
export LD_LIBRARY_PATH=${AOCLROOT}/lib:${LD_LIBRARY_PATH}

# 4) OpenMP / BLIS settings
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=true
export OMP_PLACES=cores
export BLIS_ENABLE_OPENMP=1
export BLIS_CPU_EXT=ZEN3
export BLIS_DYNAMIC_SCHED=0

# 5) (Optional) keep the unset, but DON'T re-prepend /usr/lib/...
unset LD_PRELOAD

# 6) Add GPU / NVIDIA / system stuff **at the end** so it can’t override UCX
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/omp
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda-12.6/lib64:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/lib/x86_64-linux-gnu/nvshmem/12
# If you truly need the distro libs, append them LAST
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/lib/x86_64-linux-gnu

# 7) OMPI / UCX tuning
export UCX_TLS=rc_x,sm,self
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_PCI_RELAXED_ORDERING=on

# 8) Ulimits
ulimit -l unlimited
ulimit -n 65536

# 9) Run HPL – propagate LD_LIBRARY_PATH to all nodes (HPCX docs say to do this) :contentReference[oaicite:2]{index=2}
mpirun \
  --map-by ppr:16:node:PE=1 --rank-by core --bind-to core --report-bindings \
  -x LD_LIBRARY_PATH -x PATH \
  -x AOCLROOT -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x BLIS_ENABLE_OPENMP -x BLIS_CPU_EXT -x BLIS_DYNAMIC_SCHED \
  -x UCX_TLS -x UCX_IB_GPU_DIRECT_RDMA -x UCX_MEMTYPE_CACHE -x UCX_RNDV_SCHEME -x UCX_IB_PCI_RELAXED_ORDERING \
  ./xhpl

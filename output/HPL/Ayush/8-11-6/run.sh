#!/bin/bash
#SBATCH --job-name=hpl-test
#SBATCH --nodes=4
#SBATCH --ntasks=128                # 32 ranks/node * 4 nodes
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --nodelist=node1,node2,node3,node4

############################
# 0. Run from HPL dir
############################
cd /home/hpc/hpl-2.3/testing

############################
# 1. Baseline env hygiene
############################
# Prevent GPU/NCCL preload hooks from hijacking MPI collectives
unset LD_PRELOAD

# Make sure system IB / rdma-core libs win over the bundled HPC-X verbs
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

############################
# 2. HPC-X / UCX / MPI
############################
source ~/.bashrc
export HPCX_ROOT=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source ${HPCX_ROOT}/hpcx-init.sh
hpcx_load

# prefer HPC-X UCX/MPI in PATH so we get UCX 1.19 everywhere
export PATH=${HPCX_ROOT}/ucx/bin:${HPCX_ROOT}/ompi/bin:${PATH}
export LD_LIBRARY_PATH=${HPCX_ROOT}/ucx/lib:${HPCX_ROOT}/ompi/lib:${LD_LIBRARY_PATH}

############################
# 3. AOCL BLIS (CPU math lib)
############################
export AOCLROOT=/opt/AMD/aocl-5.1.0/5.1.0/gcc
export LD_LIBRARY_PATH=${AOCLROOT}/lib:${LD_LIBRARY_PATH}

# Threading / BLIS tuning
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=true
export OMP_PLACES=cores
export BLIS_ENABLE_OPENMP=1
export BLIS_CPU_EXT=ZEN3
export BLIS_DYNAMIC_SCHED=0

############################
# 4. UCX tuning
############################
# Use IB RC transport + shared memory
export UCX_TLS=rc_x,sm,self

# let UCX choose the IB port/device you want
export UCX_NET_DEVICES=mlx5_0:1

# enable RDMA rendezvous path
export UCX_RNDV_SCHEME=put_zcopy
export UCX_MEMTYPE_CACHE=y

# drop settings that assume GPU or special NIC features
unset UCX_IB_GPU_DIRECT_RDMA
unset UCX_IB_PCI_RELAXED_ORDERING

############################
# 5. ulimits
############################
ulimit -l unlimited
ulimit -n 65536
sync

############################
# 6. Launch HPL
############################
mpirun \
  --map-by ppr:32:node:PE=1 \
  --rank-by core \
  --bind-to core \
  --report-bindings \
  -x PATH -x LD_LIBRARY_PATH \
  -x AOCLROOT \
  -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x BLIS_ENABLE_OPENMP -x BLIS_CPU_EXT -x BLIS_DYNAMIC_SCHED \
  -x UCX_TLS -x UCX_NET_DEVICES -x UCX_RNDV_SCHEME \
  ./xhpl

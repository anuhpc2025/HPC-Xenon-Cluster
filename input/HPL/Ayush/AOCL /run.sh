#!/bin/bash
#SBATCH --job-name=hpl-aocl
#SBATCH --nodes=4
#SBATCH --ntasks=128
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --nodelist=node1,node2,node3,node4

source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
source "$HPCX_HOME/hpcx-init.sh"
hpcx_load

# === AOCL BLIS ===
export AOCLROOT=/opt/AMD/aocl-5.1.0/5.1.0/gcc

# Build LD_LIBRARY_PATH once (highest priority first)
export LD_LIBRARY_PATH="$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$AOCLROOT/lib_LP64:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

# CPU-only HPL: avoid CUDA/NCCL/NVSHMEM libs and LD_PRELOADs
unset LD_PRELOAD

# OpenMP/BLIS threading
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=true
export OMP_PLACES=cores
export BLIS_NUM_THREADS=$OMP_NUM_THREADS

# === UCX selection (you verified mlx5_0:1 exists everywhere) ===
export UCX_NET_DEVICES=mlx5_0:1
export UCX_TLS=rc_mlx5,sm,self
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_PCI_RELAXED_ORDERING=on
# If you are on RoCE and need a specific GID (common on VLANs), uncomment:


# === Open MPI knobs ===
export OMPI_MCA_pml=ucx
export OMPI_MCA_btl=^vader,tcp,openib,uct

# Disable HCOLL & UCC (they’re causing the coll_hcoll init errors)
export OMPI_MCA_coll_hcoll_enable=0
export OMPI_MCA_coll_ucc_enable=0

# === PMIx/OOB control plane interface pinning ===
# Use your routable mgmt/LAN NIC (replace eno1np0 if different)
export OMPI_MCA_oob_tcp_if_include=eno1np0
export PMIX_MCA_ptl_tcp_if_include=eno1np0

# Helpful logging while debugging:
# export UCX_LOG_LEVEL=info
# export OMPI_MCA_btl_base_verbose=0

# Limits
ulimit -l unlimited
ulimit -n 65536

# Run HPL
mpirun ./xhpl
#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=8        # CPU cores per MPI task
#SBATCH --gres=gpu:4,ib:1
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --nodelist=node1,node2

# Load MPI module (adjust for your system)
# module load openmpi
export HPL_USE_GPU=1
export HPL_CUDA_MODE=1

export PATH=/opt/ompi-4.1.6/bin:$PATH
export LD_LIBRARY_PATH=/opt/ompi-4.1.6/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nvshmem:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nccl:/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib:$LD_LIBRARY_PATH


# NCCL: force IB, forbid TCP fallback
export NCCL_DEBUG=WARN
export NCCL_NET=IB
export NCCL_IB_DISABLE=0
export NCCL_IB_GID_INDEX=0
export NCCL_IB_HCA=${IB_DEV}
# If a TCP fallback ever happens, make it go over IPoIB, not Ethernet
[ -n "$IB_IF" ] && export NCCL_SOCKET_IFNAME="$IB_IF"
# Optional perf tweaks for A100 + ConnectX
export NCCL_IB_PCI_RELAXED_ORDERING=1


# UCX: force RDMA over InfiniBand (no TCP), enable GPU-direct
# Use mlx5_* names from ibdev2netdev; default to mlx5_0:1 if detection fails
IB_DEV=$(ibdev2netdev 2>/dev/null | awk '/\(Up\)|ACTIVE/{print $1}' | head -n1)
[ -z "$IB_DEV" ] && IB_DEV=mlx5_0
export UCX_TLS=rc,sm,self,cuda_copy,gdr_copy,rdmacm
export UCX_NET_DEVICES=${IB_DEV}:1
export UCX_SOCKADDR_TLS_PRIORITY=rdmacm
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_LOG_LEVEL=warn

# Make sure we use 1 GPU per task, and Slurm binds by locality
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-8}
export OMP_PLACES=cores
export OMP_PROC_BIND=close

# Open MPI over UCX only (no TCP/openib BTL fallback)
export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_btl=^tcp,openib

# Optional: ensure OMPI control path (OOB/B TL TCP) uses IPoIB if it is used at all
# (not strictly necessary with srun+PMIx, but safe)
IB_IF=$(ibdev2netdev 2>/dev/null | awk '/\(Up\)|ACTIVE/{print $5}' | head -n1)
[ -n "$IB_IF" ] && export OMPI_MCA_oob_tcp_if_include="$IB_IF" OMPI_MCA_btl_tcp_if_include="$IB_IF"

#testing
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun ./xhpl-nvidia
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


#testing
ulimit -l unlimited
ulimit -n 65536

# Run the MPI program
mpirun ./xhpl-nvidia
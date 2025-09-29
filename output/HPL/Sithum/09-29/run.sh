#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=128              # Total MPI tasks
#SBATCH --ntasks-per-node=32       # MPI tasks per node
#SBATCH --cpus-per-task=1         # CPU cores per MPI task
#SBATCH --time=00:10:00           # Time limit hh:mm:ss
#SBATCH --output=hpl-%j.out       # Standard output file
#SBATCH --error=hpl-%j.err        # Standard error file
#SBATCH --nodes=4                 # Number of nodes
#SBATCH --nodelist=node1,node2,node3,node4    # nodes 1 and 2 are the only ones with hpcx for now


# Load HPCX
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
export LD_LIBRARY_PATH=$HPCX_HOME/ucx/lib:$HPCX_HOME/ompi/lib:$LD_LIBRARY_PATH
export PATH=$HPCX_HOME/ompi/bin:$PATH
source $HPCX_HOME/hpcx-init.sh
hpcx_load

# OMPI / UCX tuning
export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_btl=^openib
export OMPI_MCA_opal_cuda_support=true
export OMPI_MCA_mpi_leave_pinned=1
export OMPI_MCA_rmaps_base_mapping_policy="ppr:2:numa:pe=8"
export OMPI_MCA_hwloc_base_binding_policy=core

export UCX_TLS=rc_x,sm,self,cuda_copy,gdr_copy,cuda_ipc
export UCX_IB_GPU_DIRECT_RDMA=y
export UCX_MEMTYPE_CACHE=y
export UCX_RNDV_SCHEME=put_zcopy
export UCX_IB_PCI_RELAXED_ORDERING=on

# Ulimits
ulimit -l unlimited
ulimit -n 65536

# Run
mpirun ./xhpl-nvidia
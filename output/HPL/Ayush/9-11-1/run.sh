#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=128              # Total MPI tasks
#SBATCH --ntasks-per-node=32       # MPI tasks per node
#SBATCH --cpus-per-task=1         # CPU cores per MPI task
#SBATCH --time=12:00:00           # Time limit hh:mm:ss
#SBATCH --nodes=4                 # Number of nodes
#SBATCH --nodelist=node1,node2,node3,node4    

# Load HPCX
source ~/.bashrc
export HPCX_HOME=/home/hpc/hpcx/hpcx-v2.24-gcc-doca_ofed-ubuntu24.04-cuda13-x86_64
export PATH=${HPCX_HOME}/ucx/bin:${HPCX_HOME}/ompi/bin:${PATH}
export LD_LIBRARY_PATH=${HPCX_HOME}/ucx/lib:${HPCX_HOME}/ompi/lib:${LD_LIBRARY_PATH}
source ${HPCX_HOME}/hpcx-init.sh
hpcx_load

# === AOCL BLIS ===
export AOCLROOT=/opt/AMD/aocl-5.1.0/5.1.0/gcc
export LD_LIBRARY_PATH=${AOCLROOT}/lib:$LD_LIBRARY_PATH
export BLIS_ENABLE_OPENMP=1
export BLIS_CPU_EXT=ZEN3        
export BLIS_DYNAMIC_SCHED=0


# --- OpenMP for HPL (MPI-only run) ---
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=true
export OMP_PLACES=cores

# ---- NCCL choice: use system 2.27.7 ----
unset LD_PRELOAD
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu

# OMPI / UCX tuning
export UCX_TLS=rc_x,sm,self
export UCX_NET_DEVICES=mlx5_0:1
export UCX_RNDV_SCHEME=put_zcopy

export OMPI_MCA_pml=ucx
export OMPI_MCA_osc=ucx
export OMPI_MCA_btl=^vader,tcp,openib


# Avoid UCC/HCOLL/SHARP (prevents weird hangs on CPU-only jobs)
export OMPI_MCA_coll_ucc_enable=0
export OMPI_MCA_coll_hcoll_enable=0
export OMPI_MCA_coll_sharp_enable=0
export OMPI_MCA_coll="^ucc,hcoll,sharp"

#Numa binding locality
export OMPI_MCA_hwloc_base_binding_policy=core
export OMPI_MCA_hwloc_base_mem_bind_policy=local_only


# Ulimits
ulimit -l unlimited
ulimit -n 65536
sync

# Run the MPI program
mpirun \
  --map-by ppr:16:socket:PE=1 --rank-by core --bind-to core --report-bindings \
  -x PATH -x LD_LIBRARY_PATH \
  -x AOCLROOT -x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES \
  -x BLIS_ENABLE_OPENMP -x BLIS_CPU_EXT -x BLIS_DYNAMIC_SCHED \
  -x OMPI_MCA_pml -x OMPI_MCA_osc -x OMPI_MCA_btl \
  -x OMPI_MCA_coll_ucc_enable -x OMPI_MCA_coll_hcoll_enable -x OMPI_MCA_coll_sharp_enable -x OMPI_MCA_coll \
  -x UCX_TLS -x UCX_NET_DEVICES -x UCX_RNDV_SCHEME \
  ./xhpl
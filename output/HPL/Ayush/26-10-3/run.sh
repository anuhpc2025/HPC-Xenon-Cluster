#!/bin/bash
#SBATCH --job-name=hpl-hero
#SBATCH --nodes=4
#SBATCH --ntasks=256             
#SBATCH --ntasks-per-node=64     
#SBATCH --cpus-per-task=1
#SBATCH --time=24:00:00

# --- Spack / env setup ---
export SPACK_USER_CONFIG_PATH=/tmp/spack-config
export SPACK_USER_CACHE_PATH=/tmp/spack-cache
export SPACK_ROOT=/opt/spack
source ${SPACK_ROOT}/share/spack/setup-env.sh

# Load the exact OpenMPI + AOCL-tuned HPL you built
spack load /buou2hh         
spack load hpl %aocc 


export PATH=$(spack location -i /buou2hh)/bin:$PATH
export LD_LIBRARY_PATH=$(spack location -i /buou2hh)/lib:$LD_LIBRARY_PATH

# --- MPI transport / launch ---
unset OMPI_MCA_osc                      # avoid shared memory RMA oddities
export OMPI_MCA_btl=self,vader,tcp      # tcp over Ethernet
export OMPI_MCA_btl_tcp_if_include=eth0
export OMPI_MCA_oob_tcp_if_include=eth0
export OMPI_MCA_pml=ob1

# Let OpenMPI auto-pick collective algs at this scale
unset OMPI_MCA_coll_tuned_use_dynamic_rules
unset OMPI_MCA_coll_tuned_bcast_algorithm
unset OMPI_MCA_coll_tuned_allreduce_algorithm

# Slurm integration (mpirun knows we're under Slurm)
export OMPI_MCA_plm=slurm
unset OMPI_MCA_orte_launch

# --- Threading / binding ---
export OMP_NUM_THREADS=1           # 1 thread per rank, critical
export BLIS_NUM_THREADS=1          # force AOCL BLIS single-thread
export OMP_PLACES=cores
export OMP_PROC_BIND=close         # keep rank near its core/L3

# BLIS low-level knobs: keep them simple and consistent with 1 thread.
export BLIS_ENABLE_OPENMP=0       
export BLIS_DYNAMIC_SCHED=0
export BLIS_JC_NT=1
export BLIS_IC_NT=1
export BLIS_JR_NT=1
export BLIS_IR_NT=1

# Tell OMPI/hwloc: bind to physical cores, not SMT siblings
export OMPI_MCA_hwloc_base_binding_policy=core
export OMPI_MCA_hwloc_base_use_hwthreads_as_cpus=0

# --- System hygiene ---
ulimit -l unlimited
ulimit -n 65536
sync   

numactl --interleave=all \
  mpirun --bind-to core --map-by ppr:64:node:pe=1 --report-bindings \
    $(spack location -i hpl)/bin/xhpl
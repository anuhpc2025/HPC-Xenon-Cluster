#!/bin/bash
#SBATCH --job-name=sst-halo-test        # Job name
#SBATCH --ntasks=2                      # 2 SST MPI ranks total
#SBATCH --ntasks-per-node=1            # 1 rank per node
#SBATCH --cpus-per-task=4              # SST threads per rank
#SBATCH --time=00:05:00                # Time limit hh:mm:ss
#SBATCH --nodes=2                      # Use 2 nodes
#SBATCH --nodelist=node1,node2         # Adjust to your actual node names
#SBATCH --output=/home/hpc/logs/%x-%j.out


########################################
# 1. Basic environment
########################################

# If you need modules for SST, uncomment (and ensure it's MPI-enabled):
# module load sst-core sst-elements

ulimit -l unlimited
ulimit -n 65536

########################################
# 2. Paths & work dir
########################################

SST_WORKDIR=/home/hpc/Programs/sst-scc-practice/network
cd "${SST_WORKDIR}"

APPPY=./scc-network.py

# Optional: also log to a file per job
OUT_BASE=/home/hpc/sst-runs
OUT_DIR="${OUT_BASE}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}"
mkdir -p "${OUT_DIR}"
LOG_FILE="${OUT_DIR}/sst.log"

########################################
# 3. Hard-coded tiny workload (no env overrides)
########################################

app="halo"
g=5          # groups
j=2          # jobs
k=2          # iters (reduced from 10 to make it extra quick)

LINK_BW="25GB/s"
ROUTER_LAT="100ns"
LINK_LAT="50ns"

threads="${SLURM_CPUS_PER_TASK}"   # 4 threads per rank
ranks="${SLURM_NTASKS}"            # 2 MPI ranks total

########################################
# 4. Run SST across 2 nodes
########################################

echo "SST_RUN_START job=${SLURM_JOB_ID} hosts=${SLURM_JOB_NODELIST} ranks=${ranks} threads=${threads} \
app=${app} groups=${g} jobs=${j} iters=${k} \
link_bw=${LINK_BW} router_latency=${ROUTER_LAT} link_latency=${LINK_LAT}" \
  | tee "${LOG_FILE}"

# Use srun to launch sst on all ranks
srun sst \
  --num-threads="${threads}" \
  "${APPPY}" -- \
    --app "${app}" \
    --groups "${g}" \
    --jobs "${j}" \
    --iters "${k}" \
    --link_bw "${LINK_BW}" \
    --router_latency "${ROUTER_LAT}" \
    --link_latency "${LINK_LAT}" \
  2>&1 | tee -a "${LOG_FILE}"

# Capture sst's exit code from the pipeline (from srun/sst)
RET=${PIPESTATUS[0]}

echo "SST_RUN_COMPLETE job=${SLURM_JOB_ID} exit_code=${RET}" | tee -a "${LOG_FILE}"

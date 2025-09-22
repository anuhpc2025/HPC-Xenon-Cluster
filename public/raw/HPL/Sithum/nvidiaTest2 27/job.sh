#!/bin/bash
#SBATCH --job-name=hpl-test       # Job name
#SBATCH --ntasks=4                # Total MPI tasks
#SBATCH --cpus-per-task=4         # CPU cores per MPI task
#SBATCH --time=01:00:00           # Time limit hh:mm:ss
#SBATCH --nodelist=node1
#SBATCH --gres=gpu:4

# Load MPI module (adjust for your system)
# module load openmpi
export LD_LIBRARY_PATH=/opt/nvidia/nvidia_hpc_benchmarks_openmpi/lib/nvshmem/:$LD_LIBRARY_PATH

#testing
ulimit -l unlimited
ulimit -n 65536

cat <<EOF > run_hpl_check_env.sh
#!/bin/bash
# This script will be executed by each MPI rank
echo "MPI Rank: \$OMPI_COMM_WORLD_RANK, Local Rank: \$OMPI_COMM_WORLD_LOCAL_RANK, CUDA_VISIBLE_DEVICES: \$CUDA_VISIBLE_DEVICES"
./xhpl-nvidia
EOF
chmod +x run_hpl_check_env.sh

# Run the MPI program using mpirun and the wrapper script
mpirun ./run_hpl_check_env.sh
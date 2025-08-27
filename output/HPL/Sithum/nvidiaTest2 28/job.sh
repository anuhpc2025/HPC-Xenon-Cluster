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

cat <<EOF > run_hpl_gpu_assign.sh
#!/bin/bash
# Set CUDA_VISIBLE_DEVICES based on the local MPI rank (0, 1, 2, 3 for 4 ranks on one node)
# This will override any existing CUDA_VISIBLE_DEVICES in the child process's environment
export CUDA_VISIBLE_DEVICES=\$OMPI_COMM_WORLD_LOCAL_RANK

# Print which GPU each rank is using for verification
echo "MPI Rank: \$OMPI_COMM_WORLD_RANK, Local Rank: \$OMPI_COMM_WORLD_LOCAL_RANK, CUDA_VISIBLE_DEVICES: \$CUDA_VISIBLE_DEVICES"

# Execute the HPL benchmark
./xhpl
EOF

chmod +x run_hpl_gpu_assign.sh

mpirun ./run_hpl_gpu_assign.sh
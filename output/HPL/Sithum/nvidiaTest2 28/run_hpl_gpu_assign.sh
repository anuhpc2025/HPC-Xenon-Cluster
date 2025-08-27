#!/bin/bash
# Set CUDA_VISIBLE_DEVICES based on the local MPI rank (0, 1, 2, 3 for 4 ranks on one node)
# This will override any existing CUDA_VISIBLE_DEVICES in the child process's environment
export CUDA_VISIBLE_DEVICES=$OMPI_COMM_WORLD_LOCAL_RANK

# Print which GPU each rank is using for verification
echo "MPI Rank: $OMPI_COMM_WORLD_RANK, Local Rank: $OMPI_COMM_WORLD_LOCAL_RANK, CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"

# Execute the HPL benchmark
./xhpl

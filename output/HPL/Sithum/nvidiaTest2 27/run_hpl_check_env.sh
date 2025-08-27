#!/bin/bash
# This script will be executed by each MPI rank
echo "MPI Rank: $OMPI_COMM_WORLD_RANK, Local Rank: $OMPI_COMM_WORLD_LOCAL_RANK, CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"
./xhpl

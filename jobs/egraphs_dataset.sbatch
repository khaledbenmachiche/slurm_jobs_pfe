#!/bin/bash
#SBATCH --job-name=egraphs-dataset
#SBATCH --partition=compute
#SBATCH --qos=c2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64GB
#SBATCH --time=4-00:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=kb5253@nyu.edu

#
# SLURM job for egraphs dataset generation
# This is a wrapper that calls the job-specific script
#

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the job-specific script
JOB_SCRIPT="$PROJECT_ROOT/scripts/job_specific/egraphs_dataset.sh"

if [[ ! -f "$JOB_SCRIPT" ]]; then
    echo "ERROR: Job script not found: $JOB_SCRIPT"
    exit 1
fi

# Optional: Source configuration file if it exists
CONFIG_FILE="$PROJECT_ROOT/configs/egraphs_dataset.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Execute the job script
bash "$JOB_SCRIPT"

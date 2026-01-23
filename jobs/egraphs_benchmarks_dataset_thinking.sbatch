#!/bin/bash
#SBATCH --job-name=egraphs_benchmarks_dataset_thinking
#SBATCH --partition=compute
#SBATCH --qos=c2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=4-00:00:00
#SBATCH --output=/scratch/kb5253/slurm_jobs_pfe/logs/jobs/egraphs_benchmarks_dataset_thinking/job_%j_%Y%m%d_%H%M%S.log
#SBATCH --error=/scratch/kb5253/slurm_jobs_pfe/logs/jobs/egraphs_benchmarks_dataset_thinking/job_%j_%Y%m%d_%H%M%S.err

PROJECT_ROOT="/scratch/kb5253/slurm_jobs_pfe"
# Setup log directory
mkdir -p "$(dirname "$0")/../../logs/jobs/egraphs_benchmarks_dataset_thinking"

# Verify project root exists
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "ERROR: Project root not found: $PROJECT_ROOT"
    exit 1
fi

# Source the job-specific script
JOB_SCRIPT="$PROJECT_ROOT/scripts/job_specific/egraphs_benchmarks_dataset_thinking.sh"

if [[ ! -f "$JOB_SCRIPT" ]]; then
    echo "ERROR: Job script not found: $JOB_SCRIPT"
    exit 1
fi

# Load configuration
CONFIG_FILE="$PROJECT_ROOT/configs/egraphs_benchmarks_dataset_thinking.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Execute the job script
bash "$JOB_SCRIPT"

#!/bin/bash
#SBATCH --job-name=egraphs_benchmarks_dataset_thinking_openrouter
#SBATCH --partition=compute
#SBATCH --qos=c2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=4-00:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=kb5253@nyu.edu

PROJECT_ROOT="/scratch/kb5253/slurm_jobs_pfe"
# Setup log directory
mkdir -p "/home/kb5253/slurm_jobs_pfe/logs/jobs/egraphs_benchmarks_dataset_thinking_openrouter"

# Verify project root exists
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "ERROR: Project root not found: $PROJECT_ROOT"
    exit 1
fi

# Source the job-specific script
JOB_SCRIPT="$PROJECT_ROOT/scripts/job_specific/egraphs_benchmarks_dataset_thinking_openrouter.sh"

if [[ ! -f "$JOB_SCRIPT" ]]; then
    echo "ERROR: Job script not found: $JOB_SCRIPT"
    exit 1
fi

# Load configuration
CONFIG_FILE="$PROJECT_ROOT/configs/egraphs_benchmarks_dataset_thinking_openrouter.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Execute the job script
bash "$JOB_SCRIPT"

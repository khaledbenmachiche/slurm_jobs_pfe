#!/bin/bash
#SBATCH --job-name=jupyter-notebook
#SBATCH --partition=nvidia
#SBATCH --qos=c2
#SBATCH --gres=gpu:a100:1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --output=/scratch/kb5253/slurm_jobs_pfe/logs/jobs/jupyter_notebook/job_%j_%Y%m%d_%H%M%S.log
#SBATCH --error=/scratch/kb5253/slurm_jobs_pfe/logs/jobs/jupyter_notebook/job_%j_%Y%m%d_%H%M%S.err

PROJECT_ROOT="/scratch/kb5253/slurm_jobs_pfe"

# Verify project root exists
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "ERROR: Project root not found: $PROJECT_ROOT"
    exit 1
fi

# Source the job-specific script
JOB_SCRIPT="$PROJECT_ROOT/scripts/job_specific/jupyter_notebook.sh"

if [[ ! -f "$JOB_SCRIPT" ]]; then
    echo "ERROR: Job script not found: $JOB_SCRIPT"
    exit 1
fi

# Load configuration
CONFIG_FILE="$PROJECT_ROOT/configs/jupyter_notebook.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Execute the job script
bash "$JOB_SCRIPT"

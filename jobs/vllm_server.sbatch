#!/bin/bash
#SBATCH --job-name=vllm-server
#SBATCH --partition=nvidia
#SBATCH --qos=c2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64GB
#SBATCH --gres=gpu:a100:2
#SBATCH --time=2-00:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=kb5253@nyu.edu

#
# SLURM job for vLLM inference server
# Runs vLLM server with GPU support for model inference
#

# Use absolute path to project root (adjust this to your actual path)
PROJECT_ROOT="/scratch/kb5253/slurm_jobs_pfe"

# Verify project root exists
if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "ERROR: Project root not found: $PROJECT_ROOT"
    exit 1
fi

# Source the job-specific script
JOB_SCRIPT="$PROJECT_ROOT/scripts/job_specific/vllm_server.sh"

if [[ ! -f "$JOB_SCRIPT" ]]; then
    echo "ERROR: Job script not found: $JOB_SCRIPT"
    exit 1
fi

# Optional: Source configuration file if it exists
CONFIG_FILE="$PROJECT_ROOT/configs/vllm_server.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Execute the job script
bash "$JOB_SCRIPT"

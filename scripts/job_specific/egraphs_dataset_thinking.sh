#!/bin/bash

# Exit on error
set -e
set -o pipefail

# Get scripts directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/env_setup.sh"
source "$SCRIPT_DIR/cleanup.sh"

# Job configuration
JOB_NAME="egraphs_dataset_thinking"

# Initialize logging
setup_job_logging "$JOB_NAME"
log_job_header "$JOB_NAME"

# Setup cleanup trap
setup_cleanup_trap

# Main execution
main() {
    log_info "Starting CoT (Thinking) Dataset Generation Job..."

    # 1. Setup Environment
    # No CUDA needed for API client
    
    # Load miniconda module to make conda command available
    log_info "Loading miniconda module..."
    if ! load_modules miniconda/3-4.11.0; then
        log_error "Failed to load miniconda module"
        return 1
    fi
    log_info "Miniconda module loaded successfully"
    
    CONDA_ENV_NAME="/scratch/kb5253/conda_envs/data_generation" 
    setup_conda_env "$CONDA_ENV_NAME"

    # 2. Setup Paths
    # Updated path as per user request
    PYTHON_SCRIPT_DIR="/scratch/kb5253/chehab/data_generation"
    PYTHON_SCRIPT="$PYTHON_SCRIPT_DIR/main.py"

    if [[ ! -f "$PYTHON_SCRIPT" ]]; then
        log_error "Python script not found at: $PYTHON_SCRIPT"
        return 1
    fi
    log_info "Found python script: $PYTHON_SCRIPT"

    # Add script dir to PYTHONPATH
    export PYTHONPATH="${PYTHONPATH}:${PYTHON_SCRIPT_DIR}"

    # 3. Configure Arguments
    # Input/Output paths
    # Assuming input/output might also be relative to scratch or defined via vars
    # Defaulting to a sensible location in scratch given the script location
    INPUT_FILE="${DATASET_INPUT_FILE:-/scratch/kb5253/chehab/dataset.json}" 
    OUTPUT_FILE="${DATASET_OUTPUT_FILE:-/scratch/$USER/slurm_jobs_pfe/data/thinking_dataset_$(date +%Y%m%d_%H%M%S).jsonl}"
    
    # Ensure output directory exists
    mkdir -p "$(dirname "$OUTPUT_FILE")"

    # VLLM Configuration
    PROVIDER="vllm"
    MODEL="/scratch/kb5253/models/Qwen2.5-32B-Instruct"

    # Setup VLLM_BASE_URL if provider is vllm
    if [[ "$PROVIDER" == "vllm" ]]; then
        # Use existing env var or default
        export VLLM_BASE_URL="${VLLM_BASE_URL:-http://localhost:8000/v1}"
        log_info "Using VLLM_BASE_URL: $VLLM_BASE_URL"
    fi
    
    # Command construction
    CMD="python $PYTHON_SCRIPT \
        --input $INPUT_FILE \
        --output $OUTPUT_FILE \
        --provider $PROVIDER \
        --model $MODEL \
        --use-langfuse \
        --concurrency 1"

    log_info "Executing command:"
    log_info "$CMD"

    # 4. Run Execution
    eval "$CMD"
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_info "Dataset generation completed successfully."
        log_info "Output saved to: $OUTPUT_FILE"
    else
        log_error "Dataset generation failed with exit code: $exit_code"
        return $exit_code
    fi
}

# Execute main
if main; then
    exit 0
else
    exit 1
fi

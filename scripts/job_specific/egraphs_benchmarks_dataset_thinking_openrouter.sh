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
JOB_NAME="egraphs_benchmarks_dataset_thinking_openrouter"

# Initialize logging
setup_job_logging "$JOB_NAME"
log_job_header "$JOB_NAME"

# Setup cleanup trap
setup_cleanup_trap

# Main execution
main() {
    log_info "Starting CoT (Thinking) Benchmarks Dataset Generation Job with OpenRouter..."

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
    INPUT_FILE="${BENCHMARKS_INPUT_FILE:-/scratch/$USER/chehab/egraphs/benchmarks_traces.json}"
    OUTPUT_FILE="${BENCHMARKS_OUTPUT_FILE:-/scratch/$USER/slurm_jobs_pfe/data/thinking_benchmarks_dataset_openrouter_$(date +%Y%m%d_%H%M%S).jsonl}"
    
    # Ensure output directory exists
    mkdir -p "$(dirname "$OUTPUT_FILE")"

    # OpenRouter Configuration
    PROVIDER="openrouter"
    # Using GPT-OSS 120B free model
    MODEL="${OPENROUTER_MODEL:-openai/gpt-oss-120b:free}"
    
    # Verify OpenRouter API key is set
    if [[ -z "$OPENROUTER_API_KEY" ]]; then
        log_error "OPENROUTER_API_KEY environment variable is not set"
        log_error "Please set your OpenRouter API key before running this job"
        return 1
    fi
    log_info "OpenRouter API key found"
    
    # Command construction
    CMD="python $PYTHON_SCRIPT \
        --input $INPUT_FILE \
        --output $OUTPUT_FILE \
        --provider $PROVIDER \
        --model $MODEL \
        --use-langfuse \
        --concurrency ${CONCURRENCY:-10}"

    log_info "Executing command:"
    log_info "$CMD"

    # 4. Run Execution
    eval "$CMD"
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_info "Benchmarks generation completed successfully."
        log_info "Output saved to: $OUTPUT_FILE"
    else
        log_error "Benchmarks generation failed with exit code: $exit_code"
        return $exit_code
    fi
}

# Execute main
if main; then
    exit 0
else
    exit 1
fi

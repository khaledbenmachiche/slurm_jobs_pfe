#!/bin/bash

set -e
set -o pipefail

# Get scripts directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/env_setup.sh"
source "$SCRIPT_DIR/cleanup.sh"

# Job configuration
JOB_NAME="jupyter_notebook"

# Initialize logging
setup_job_logging "$JOB_NAME"
log_job_header "$JOB_NAME"

# Setup cleanup trap
setup_cleanup_trap

# Function to setup cache environments
setup_cache_environment() {
    log_info "Setting up cache environments..."
    
    # Use config values or defaults
    local hf_cache="${HF_CACHE_DIR:-/scratch/$USER/cache/hf}"
    local torch_cache="${TORCH_CACHE_DIR:-/scratch/$USER/cache/torch}"
    
    ensure_directory "$hf_cache"
    ensure_directory "$torch_cache"
    
    export HF_HOME="$hf_cache"
    export HF_DATASETS_CACHE="$hf_cache"
    export TORCH_HOME="$torch_cache"
    export XDG_CACHE_HOME="/scratch/$USER/cache"
    
    log_info "Cache directories configured:"
    log_info "  HF_HOME: $HF_HOME"
    log_info "  TORCH_HOME: $TORCH_HOME"
}

# Function to check GPU availability
check_gpu() {
    log_info "Checking GPU availability..."
    
    if command -v nvidia-smi &> /dev/null; then
        log_info "GPU Information:"
        nvidia-smi --query-gpu=index,name,memory.total,memory.free --format=csv
    else
        log_warn "nvidia-smi not found, cannot verify GPU. Ensure you are on a GPU node."
    fi
}

# Main job function
main() {
    log_info "Starting Jupyter Notebook job with GPU support..."
    
    # Load configuration
    CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../configs" && pwd)/jupyter_notebook.conf"
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log_warn "Configuration file not found: $CONFIG_FILE. Using defaults."
        CONDA_ENV="jupyterlab"
        JUPYTER_CMD="jupyter-lab"
    fi

    # Setup environment
    log_info "Loading CUDA module..."
    load_modules cuda/12.2.0 || log_warn "Failed to load cuda/12.2.0"
    
    setup_cache_environment
    
    setup_conda_env "$CONDA_ENV"
    
    # Check GPU
    check_gpu
    
    # Get a random available port between 8000 and 9999
    local port
    while true; do
        port=$((RANDOM % 2000 + 8000))
        if ! ss -tuln | grep -q ":$port "; then
            break
        fi
    done
    
    log_info "Selected port: $port"
    
    # Get compute node hostname
    local node_hostname=$(hostname)
    local user_name=$USER
    
    # Connection instructions
    log_separator "="
    log_info "JUPYTER NOTEBOOK CONNECTION INSTRUCTIONS"
    log_separator "-"
    log_info "1. Run this command on your LOCAL machine:"
    log_info "   ssh -N -L ${port}:${node_hostname}:${port} ${user_name}@login1.nyuad.nyu.edu"
    log_info ""
    log_info "2. Open this URL in your browser:"
    log_info "   http://localhost:${port}"
    log_separator "="
    
    # Start Jupyter
    log_info "Launching $JUPYTER_CMD on port $port..."
    
    # Run jupyter and capture output to log
    # Added --ip=0.0.0.0 to listen on all interfaces for the tunnel
    $JUPYTER_CMD --no-browser --port=$port --ip=0.0.0.0 --NotebookApp.token='' --NotebookApp.password=''
    
    return 0
}

# Execute main function
if main; then
    exit_code=0
    log_job_footer $exit_code
    exit $exit_code
else
    exit_code=$?
    log_job_footer $exit_code
    exit $exit_code
fi

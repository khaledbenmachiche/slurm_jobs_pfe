#!/bin/bash
#
# Job-specific script for vLLM server
# Runs vLLM inference server with GPU support
#

set -e
set -o pipefail

# Get the absolute path to the scripts directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/logging.sh" || { echo "Failed to source logging.sh"; exit 1; }
source "$SCRIPT_DIR/env_setup.sh" || { echo "Failed to source env_setup.sh"; exit 1; }
source "$SCRIPT_DIR/cleanup.sh" || { echo "Failed to source cleanup.sh"; exit 1; }

# Job configuration
JOB_NAME="vllm_server"

# Default configuration (can be overridden by config file or environment variables)
: ${MODEL_PATH:="/scratch/kb5253/models/Qwen2.5-32B-Instruct"}
: ${DTYPE:="auto"}
: ${MAX_MODEL_LEN:=8192}
: ${GPU_MEMORY_UTILIZATION:=0.9}
: ${TENSOR_PARALLEL_SIZE:=1}
: ${HOST:="0.0.0.0"}
: ${PORT:=8000}
: ${HF_CACHE_DIR:="/scratch/kb5253/hf_cache"}
: ${CONDA_ENV:="/scratch/kb5253/conda_envs/vllm"}

# Initialize logging
setup_job_logging "$JOB_NAME"
log_job_header "$JOB_NAME"

# Setup cleanup trap
setup_cleanup_trap


# Function to setup cache environments (HF, PyTorch, vLLM, etc.)
setup_cache_environment() {
    log_info "Setting up cache environments..."
    
    # Base cache directory on scratch (to avoid disk quota issues in home)
    local BASE_CACHE_DIR="/scratch/kb5253/cache"
    
    # Create all cache subdirectories
    local cache_dirs=("hf" "torch" "vllm" "torch_compile")
    for dir in "${cache_dirs[@]}"; do
        if ! ensure_directory "$BASE_CACHE_DIR/$dir"; then
            log_error "Failed to create cache directory: $BASE_CACHE_DIR/$dir"
            return 1
        fi
    done
    
    # HuggingFace / Transformers cache
    export HF_HOME="$BASE_CACHE_DIR/hf"
    export HF_DATASETS_CACHE="$BASE_CACHE_DIR/hf"
    
    # PyTorch cache
    export TORCH_HOME="$BASE_CACHE_DIR/torch"
    
    # vLLM cache
    export VLLM_CACHE_DIR="$BASE_CACHE_DIR/vllm"
    
    # Torch compile / dynamo cache (critical to avoid home disk quota)
    export TORCH_COMPILE_CACHE_DIR="$BASE_CACHE_DIR/torch_compile"
    export TORCHDYNAMO_CACHE_DIR="$BASE_CACHE_DIR/torch_compile"
    
    # General XDG fallback
    export XDG_CACHE_HOME="$BASE_CACHE_DIR"
    
    log_info "Cache directories configured:"
    log_info "  HF_HOME: $HF_HOME"
    log_info "  TORCH_HOME: $TORCH_HOME"
    log_info "  VLLM_CACHE_DIR: $VLLM_CACHE_DIR"
    log_info "  TORCH_COMPILE_CACHE_DIR: $TORCH_COMPILE_CACHE_DIR"
    log_info "  XDG_CACHE_HOME: $XDG_CACHE_HOME"
}

# Function to check GPU availability
check_gpu() {
    log_info "Checking GPU availability..."
    
    if command -v nvidia-smi &> /dev/null; then
        log_info "GPU Information:"
        nvidia-smi --query-gpu=index,name,memory.total,memory.free --format=csv
    else
        log_warn "nvidia-smi not found, cannot verify GPU"
    fi
}

# Main job function
main() {
    log_info "Starting vLLM server job main function..."

    # Load required modules (cuda/12.2.0 will also load gcc/9.2.0 as dependency)
    log_info "Loading required modules..."
    if ! load_modules cuda/12.2.0; then
        log_warn "Could not load module cuda/12.2.0; continuing without it"
    else
        log_info "Modules loaded successfully"
    fi
    
    # Setup cache environments (HF, PyTorch, vLLM, Torch compile)
    log_info "Setting up cache environments..."
    setup_cache_environment || {
        log_error "Failed to setup cache environment"
        return 1
    }
    log_info "Cache environment setup complete"
    
    # Verify vllm command is available
    # Activate conda environment
    log_info "Activating Conda environment: $CONDA_ENV"
    if ! setup_conda_env "$CONDA_ENV"; then
        log_error "Failed to activate conda env: $CONDA_ENV"
        return 1
    fi

    verify_command vllm || {
        log_error "vllm command not found. Make sure vllm is installed."
        log_info "Install with: pip install vllm or activate appropriate environment"
        return 1
    }
    
    log_info "vLLM version: $(vllm --version 2>&1 || echo 'unknown')"
    
    # Check GPU availability
    log_info "Checking GPU availability..."
    check_gpu
    log_info "GPU check complete"
    
    # Verify model path
    log_info "Verifying model path: $MODEL_PATH"
    verify_directory "$MODEL_PATH" "Model directory" || {
        log_error "Model directory verification failed"
        return 1
    }
    log_info "Model path verified successfully"
    
    # Print configuration
    log_separator "="
    log_info "vLLM Server Configuration:"
    log_info "  Model: $MODEL_PATH"
    log_info "  Data type: $DTYPE"
    log_info "  Max model length: $MAX_MODEL_LEN"
    log_info "  GPU memory utilization: $GPU_MEMORY_UTILIZATION"
    log_info "  Host: $HOST"
    log_info "  Port: $PORT"
    log_info "  Node: ${SLURM_NODELIST:-$(hostname)}"
    log_separator "="
    
    # Create PID file for server management
    local pid_file="$JOB_LOG_DIR/vllm_server.pid"
    
    # Start vLLM server
    log_info "Starting vLLM server..."
    log_info "Server will be accessible at http://$(hostname):$PORT"
    log_info "Command: vllm serve \"$MODEL_PATH\" --dtype \"$DTYPE\" --max-model-len \"$MAX_MODEL_LEN\" --gpu-memory-utilization \"$GPU_MEMORY_UTILIZATION\" --tensor-parallel-size \"$TENSOR_PARALLEL_SIZE\" --host \"$HOST\" --port \"$PORT\""
    log_separator "="
    
    # Run vllm server (this will block)
    log_info "Executing vllm serve command..."
    vllm serve "$MODEL_PATH" \
        --dtype "$DTYPE" \
        --max-model-len "$MAX_MODEL_LEN" \
        --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
        --tensor-parallel-size "$TENSOR_PARALLEL_SIZE" \
        --host "$HOST" \
        --port "$PORT" &
    
    local vllm_pid=$!
    echo "$vllm_pid" > "$pid_file"
    log_info "vLLM server started with PID: $vllm_pid"
    log_info "PID saved to: $pid_file"
    
    # Register cleanup to kill the server on exit
    register_cleanup "kill $vllm_pid 2>/dev/null || true"
    
    # Wait for server to start
    log_info "Waiting for server to initialize..."
    sleep 10
    
    # Check if server is running
    if ps -p $vllm_pid > /dev/null; then
        log_info "vLLM server is running"
        
        # Test server endpoint
        log_info "Testing server endpoint..."
        if command -v curl &> /dev/null; then
            if curl -s "http://localhost:$PORT/health" > /dev/null 2>&1; then
                log_info "Server health check: OK"
            else
                log_warn "Server health check failed (server may still be initializing)"
            fi
        fi
        
        # Keep the job running and monitor the server
        log_info "Server is running. Monitoring..."
        log_separator "="
        
        # Monitor server process
        while ps -p $vllm_pid > /dev/null; do
            sleep 60
            log_debug "Server still running (PID: $vllm_pid)"
        done
        
        log_error "vLLM server process terminated unexpectedly"
        return 1
    else
        log_error "vLLM server failed to start"
        return 1
    fi
}

# Execute main function
log_info "About to execute main function..."
if main; then
    exit_code=0
    log_job_footer $exit_code
    exit $exit_code
else
    exit_code=$?
    log_error "Main function failed with exit code: $exit_code"
    log_job_footer $exit_code
    exit $exit_code
fi

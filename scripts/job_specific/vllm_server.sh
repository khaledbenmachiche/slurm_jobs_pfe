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
: ${MODEL_PATH:="openai/gpt-oss-120b"}
: ${DTYPE:="bfloat16"}
: ${MAX_MODEL_LEN:=131072}
: ${GPU_MEMORY_UTILIZATION:=0.92}
: ${TENSOR_PARALLEL_SIZE:=2}
: ${ENABLE_CHUNKED_PREFILL:="false"}
: ${MAX_NUM_SEQS:=1}
: ${TRUST_REMOTE_CODE:="true"}
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
    
    # Load miniconda module to make conda command available
    log_info "Loading miniconda module..."
    if ! load_modules miniconda/3-4.11.0; then
        log_error "Failed to load miniconda module"
        return 1
    fi
    log_info "Miniconda module loaded successfully"
    
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
    
    # Disable v1 engine to avoid attention sink compatibility issues
    # V1 requires compute capability 9.0+ for attention sink feature
    export VLLM_USE_V1=0
    log_info "Set VLLM_USE_V1=0 to use v0 engine (compatible with A100 GPUs)"
    
    # Disable multiprocessing frontend to force v0 engine
    export VLLM_DISABLE_FRONTEND_MULTIPROCESSING=1
    log_info "Set VLLM_DISABLE_FRONTEND_MULTIPROCESSING=1 to ensure v0 engine usage"
    
    # Workarounds for missing MOE kernels and attention backend
    export VLLM_ATTENTION_BACKEND=FLASH_ATTN
    export VLLM_USE_TRITON_FLASH_ATTN=0
    log_info "Set attention backend workarounds"
    
    log_info "vLLM version: $(vllm --version 2>&1 || echo 'unknown')"    
    # Check GPU availability
    log_info "Checking GPU availability..."
    check_gpu
    log_info "GPU check complete"
    
    # Print configuration
    log_separator "="
    log_info "vLLM Server Configuration:"
    log_info "  Model: $MODEL_PATH"
    log_info "  Data type: $DTYPE"
    log_info "  Max model length: $MAX_MODEL_LEN"
    log_info "  GPU memory utilization: $GPU_MEMORY_UTILIZATION"
    log_info "  Tensor parallel size: $TENSOR_PARALLEL_SIZE"
    log_info "  Enable chunked prefill: $ENABLE_CHUNKED_PREFILL"
    log_info "  Max num seqs: $MAX_NUM_SEQS"
    log_info "  Trust remote code: $TRUST_REMOTE_CODE"
    log_info "  Enforce eager: true"
    log_info "  Host: $HOST"
    log_info "  Port: $PORT"
    log_info "  Node: ${SLURM_NODELIST:-$(hostname)}"
    log_separator "="
    
    # Create PID file for server management
    local pid_file="$JOB_LOG_DIR/vllm_server.pid"
    
    # Start vLLM server
    log_info "Starting vLLM server..."
    log_info "Server will be accessible at http://$(hostname):$PORT"
    
    # Build the vllm command with conditional flags
    local vllm_cmd="vllm serve \"$MODEL_PATH\""
    vllm_cmd+=" --dtype \"$DTYPE\""
    vllm_cmd+=" --tensor-parallel-size \"$TENSOR_PARALLEL_SIZE\""
    vllm_cmd+=" --max-model-len \"$MAX_MODEL_LEN\""
    vllm_cmd+=" --gpu-memory-utilization \"$GPU_MEMORY_UTILIZATION\""
    vllm_cmd+=" --enforce-eager"
    vllm_cmd+=" --disable-frontend-multiprocessing"  # Force v0 engine
    [[ "$ENABLE_CHUNKED_PREFILL" == "true" ]] && vllm_cmd+=" --enable-chunked-prefill"
    vllm_cmd+=" --max-num-seqs \"$MAX_NUM_SEQS\""
    [[ "$TRUST_REMOTE_CODE" == "true" ]] && vllm_cmd+=" --trust-remote-code"
    vllm_cmd+=" --host \"$HOST\""
    vllm_cmd+=" --port \"$PORT\""
    
    log_info "Command: $vllm_cmd"
    log_separator "="
    
    # Run vllm server (this will block)
    log_info "Executing vllm serve command..."
    eval "$vllm_cmd &"
    
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
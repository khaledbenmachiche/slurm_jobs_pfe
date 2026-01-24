#!/bin/bash
#
# Environment setup utilities for SLURM jobs
# Handles module loading, path setup, and environment verification
#

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Load required modules
# Args:
#   $@: List of modules to load
load_modules() {
    log_info "Loading modules..."
    
    for module in "$@"; do
        log_info "Loading module: $module"
        if module load "$module" > /dev/null 2>&1; then
            log_info "Successfully loaded: $module"
        else
            log_error "Failed to load module: $module"
            return 1
        fi
    done
    
    log_info "All modules loaded successfully"
}

# Setup Rust/Cargo environment
setup_rust_env() {
    log_info "Setting up Rust environment..."
    
    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
        log_info "Loaded cargo environment from ~/.cargo/env"
    else
        log_warn "Cargo environment file not found: $HOME/.cargo/env"
    fi
    
    # Verify cargo is available
    if command -v cargo &> /dev/null; then
        log_info "Cargo found: $(which cargo)"
        log_info "Cargo version: $(cargo --version 2>&1)"
        return 0
    else
        log_error "cargo not found in PATH"
        log_error "PATH: $PATH"
        return 1
    fi
}

# Setup Python environment
# Args:
#   $1: Path to virtual environment (optional)
setup_python_env() {
    local venv_path="$1"
    
    log_info "Setting up Python environment..."
    
    if [[ -n "$venv_path" && -d "$venv_path" ]]; then
        log_info "Activating virtual environment: $venv_path"
        source "$venv_path/bin/activate"
        log_info "Virtual environment activated"
    fi
    
    # Verify Python is available
    if command -v python &> /dev/null; then
        log_info "Python found: $(which python)"
        log_info "Python version: $(python --version 2>&1)"
        return 0
    else
        log_error "python not found in PATH"
        return 1
    fi
}

# Setup conda environment
# Args:
#   $1: Conda environment name
setup_conda_env() {
    local env_name="${1:?Conda environment name required}"
    
    log_info "Setting up Conda environment: $env_name"
    
    # Try to find conda installation
    local conda_sh=""
    
    # Check common locations
    local conda_locations=(
        "$HOME/miniconda3/etc/profile.d/conda.sh"
        "$HOME/anaconda3/etc/profile.d/conda.sh"
        "/share/apps/NYUAD5/miniconda/3-4.11.0/etc/profile.d/conda.sh"
        "$CONDA_PREFIX/../etc/profile.d/conda.sh"
    )
    
    for location in "${conda_locations[@]}"; do
        if [[ -f "$location" ]]; then
            conda_sh="$location"
            log_info "Found conda.sh at: $conda_sh"
            break
        fi
    done
    
    # If conda.sh found, source it
    if [[ -n "$conda_sh" ]]; then
        source "$conda_sh"
        log_info "Sourced conda initialization script"
    elif command -v conda &> /dev/null; then
        # Conda command is already available (e.g., from module load)
        log_info "Conda command already available: $(which conda)"
        # Initialize conda for bash
        eval "$(conda shell.bash hook)"
    else
        log_error "Conda installation not found"
        log_error "Tried locations: ${conda_locations[*]}"
        return 1
    fi
    
    # Activate environment
    if conda activate "$env_name" > /dev/null 2>&1; then
        log_info "Conda environment activated: $env_name"
        log_info "Python version: $(python --version 2>&1)"
        return 0
    else
        log_error "Failed to activate conda environment: $env_name"
        return 1
    fi
}

# Verify command exists
# Args:
#   $1: Command name
verify_command() {
    local cmd="${1:?Command name required}"
    
    if command -v "$cmd" &> /dev/null; then
        log_info "Command verified: $cmd ($(which $cmd))"
        return 0
    else
        log_error "Command not found: $cmd"
        return 1
    fi
}

# Verify file exists
# Args:
#   $1: File path
#   $2: Description (optional)
verify_file() {
    local file_path="${1:?File path required}"
    local description="${2:-File}"
    
    if [[ -f "$file_path" ]]; then
        local size=$(du -h "$file_path" 2>/dev/null | cut -f1)
        log_info "$description verified: $file_path (size: ${size:-unknown})"
        return 0
    else
        log_error "$description not found: $file_path"
        return 1
    fi
}

# Verify directory exists
# Args:
#   $1: Directory path
#   $2: Description (optional)
verify_directory() {
    local dir_path="${1:?Directory path required}"
    local description="${2:-Directory}"
    
    if [[ -d "$dir_path" ]]; then
        log_info "$description verified: $dir_path"
        return 0
    else
        log_error "$description not found: $dir_path"
        return 1
    fi
}

# Create directory if it doesn't exist
# Args:
#   $1: Directory path
ensure_directory() {
    local dir_path="${1:?Directory path required}"
    
    if [[ ! -d "$dir_path" ]]; then
        log_info "Creating directory: $dir_path"
        mkdir -p "$dir_path"
    else
        log_debug "Directory already exists: $dir_path"
    fi
}

# Set up scratch directory
# Args:
#   $1: Project name
setup_scratch_dir() {
    local project_name="${1:?Project name required}"
    local scratch_dir="/scratch/$USER/$project_name"
    
    ensure_directory "$scratch_dir"
    export PROJECT_SCRATCH_DIR="$scratch_dir"
    
    log_info "Scratch directory: $PROJECT_SCRATCH_DIR"
}

# Setup temporary directory
setup_temp_dir() {
    local temp_dir="${TMPDIR:-/tmp}/slurm_job_${SLURM_JOB_ID:-$$}"
    
    ensure_directory "$temp_dir"
    export JOB_TEMP_DIR="$temp_dir"
    
    log_info "Temporary directory: $JOB_TEMP_DIR"
}

# Print environment summary
print_env_summary() {
    log_info "Environment Summary:"
    log_info "  Hostname: $(hostname)"
    log_info "  User: $USER"
    log_info "  PWD: $(pwd)"
    log_info "  Shell: $SHELL"
    log_info "  Job ID: ${SLURM_JOB_ID:-N/A}"
    log_info "  Node: ${SLURM_NODELIST:-N/A}"
    log_info "  CPUs: ${SLURM_CPUS_PER_TASK:-N/A}"
    log_info "  Memory: ${SLURM_MEM_PER_NODE:-N/A}"
}

# Export functions
export -f load_modules
export -f setup_rust_env
export -f setup_python_env
export -f setup_conda_env
export -f verify_command
export -f verify_file
export -f verify_directory
export -f ensure_directory
export -f setup_scratch_dir
export -f setup_temp_dir
export -f print_env_summary

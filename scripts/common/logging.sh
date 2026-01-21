#!/bin/bash
#
# Logging utilities for SLURM jobs
# Provides consistent logging format across all jobs
#

# ANSI color codes for better readability
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'

# Log level constants
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Default log level (can be overridden by setting LOG_LEVEL environment variable)
: ${LOG_LEVEL:=$LOG_LEVEL_INFO}

# Setup logging for a job
# Creates log directories and redirects stdout/stderr
# Args:
#   $1: Job name
#   $2: Base log directory (optional, defaults to logs/)
setup_job_logging() {
    local job_name="${1:?Job name required}"
    local log_base_dir="${2:-logs}"
    
    # Create log directories
    local job_log_dir="${log_base_dir}/jobs/${job_name}"
    mkdir -p "$job_log_dir"
    
    # Set global log file variables
    export JOB_LOG_DIR="$job_log_dir"
    export JOB_LOG_FILE="${job_log_dir}/job_${SLURM_JOB_ID:-local}_$(date +%Y%m%d_%H%M%S).log"
    export JOB_ERROR_FILE="${job_log_dir}/job_${SLURM_JOB_ID:-local}_$(date +%Y%m%d_%H%M%S).err"
    
    # Redirect stdout and stderr to log files
    exec > >(tee -a "$JOB_LOG_FILE")
    exec 2> >(tee -a "$JOB_ERROR_FILE" >&2)
    
    log_info "Logging initialized for job: $job_name"
    log_info "Log file: $JOB_LOG_FILE"
    log_info "Error file: $JOB_ERROR_FILE"
}

# Setup logging for a script
# Args:
#   $1: Script name
#   $2: Base log directory (optional, defaults to logs/)
setup_script_logging() {
    local script_name="${1:?Script name required}"
    local log_base_dir="${2:-logs}"
    
    # Create log directories
    local script_log_dir="${log_base_dir}/scripts/${script_name}"
    mkdir -p "$script_log_dir"
    
    # Set global log file variable
    export SCRIPT_LOG_FILE="${script_log_dir}/script_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "Script logging initialized: $script_name"
    log_info "Log file: $SCRIPT_LOG_FILE"
}

# Get timestamp for logging
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Generic log function
# Args:
#   $1: Log level (DEBUG, INFO, WARN, ERROR)
#   $2: Color code
#   $3: Message
_log() {
    local level="$1"
    local color="$2"
    shift 2
    local message="$*"
    
    if [[ -n "$color" ]]; then
        echo -e "${color}[$(get_timestamp)] [$level] $message${COLOR_RESET}"
    else
        echo "[$(get_timestamp)] [$level] $message"
    fi
}

# Log debug message
log_debug() {
    [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && _log "DEBUG" "$COLOR_CYAN" "$@"
}

# Log info message
log_info() {
    [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]] && _log "INFO" "$COLOR_GREEN" "$@"
}

# Log warning message
log_warn() {
    [[ $LOG_LEVEL -le $LOG_LEVEL_WARN ]] && _log "WARN" "$COLOR_YELLOW" "$@"
}

# Log error message
log_error() {
    [[ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && _log "ERROR" "$COLOR_RED" "$@" >&2
}

# Log a separator line
log_separator() {
    local char="${1:-=}"
    local length="${2:-80}"
    printf "${char}%.0s" $(seq 1 $length)
    echo
}

# Log job header with system information
log_job_header() {
    local job_name="${1:?Job name required}"
    
    log_separator "="
    log_info "Job Name: $job_name"
    log_info "Job ID: ${SLURM_JOB_ID:-N/A}"
    log_info "Node: ${SLURM_NODELIST:-$(hostname)}"
    log_info "User: $USER"
    log_info "Working Directory: $(pwd)"
    log_info "Start Time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_separator "="
}

# Log job footer
log_job_footer() {
    local exit_code="${1:-0}"
    
    log_separator "="
    if [[ $exit_code -eq 0 ]]; then
        log_info "Job completed successfully"
    else
        log_error "Job failed with exit code: $exit_code"
    fi
    log_info "End Time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_separator "="
}

# Log command execution
log_command() {
    log_info "Executing: $*"
}

# Log file operation
log_file_op() {
    local operation="$1"
    local file="$2"
    log_info "File $operation: $file"
}

# Log with duration
# Usage: log_duration "description" command args...
log_duration() {
    local description="$1"
    shift
    
    log_info "Starting: $description"
    local start_time=$(date +%s)
    
    "$@"
    local exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "Completed: $description (duration: ${duration}s)"
    else
        log_error "Failed: $description (duration: ${duration}s, exit code: $exit_code)"
    fi
    
    return $exit_code
}

# Export functions for use in subshells
export -f get_timestamp
export -f _log
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_separator
export -f log_job_header
export -f log_job_footer
export -f log_command
export -f log_file_op
export -f log_duration

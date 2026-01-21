#!/bin/bash
#
# Cleanup utilities for SLURM jobs
# Handles temporary file cleanup and graceful shutdown
#

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Array to store cleanup tasks
declare -a CLEANUP_TASKS=()

# Register a cleanup task
# Args:
#   $@: Command to execute during cleanup
register_cleanup() {
    local task="$*"
    CLEANUP_TASKS+=("$task")
    log_debug "Registered cleanup task: $task"
}

# Execute all registered cleanup tasks
execute_cleanup() {
    local exit_code="${1:-0}"
    
    if [[ ${#CLEANUP_TASKS[@]} -eq 0 ]]; then
        log_debug "No cleanup tasks registered"
        return 0
    fi
    
    log_info "Executing cleanup tasks (${#CLEANUP_TASKS[@]} tasks)..."
    
    local failed_tasks=0
    for task in "${CLEANUP_TASKS[@]}"; do
        log_debug "Cleanup: $task"
        if eval "$task" > /dev/null 2>&1; then
            log_debug "Cleanup task succeeded: $task"
        else
            log_warn "Cleanup task failed: $task"
            ((failed_tasks++))
        fi
    done
    
    if [[ $failed_tasks -eq 0 ]]; then
        log_info "All cleanup tasks completed successfully"
    else
        log_warn "Some cleanup tasks failed ($failed_tasks/${#CLEANUP_TASKS[@]})"
    fi
    
    # Clear the array
    CLEANUP_TASKS=()
}

# Cleanup temporary files
# Args:
#   $@: List of files/directories to remove
cleanup_files() {
    log_info "Cleaning up temporary files..."
    
    for item in "$@"; do
        if [[ -e "$item" ]]; then
            log_info "Removing: $item"
            rm -rf "$item"
        else
            log_debug "Already removed or doesn't exist: $item"
        fi
    done
}

# Cleanup temporary directory
cleanup_temp_dir() {
    if [[ -n "$JOB_TEMP_DIR" && -d "$JOB_TEMP_DIR" ]]; then
        log_info "Cleaning up temporary directory: $JOB_TEMP_DIR"
        rm -rf "$JOB_TEMP_DIR"
    fi
}

# Setup cleanup trap
# This ensures cleanup happens on EXIT, INT, TERM signals
setup_cleanup_trap() {
    trap 'execute_cleanup $?' EXIT
    trap 'log_warn "Received SIGINT"; exit 130' INT
    trap 'log_warn "Received SIGTERM"; exit 143' TERM
    
    log_debug "Cleanup trap registered"
}

# Archive logs to a specific location
# Args:
#   $1: Source log directory
#   $2: Archive destination (optional)
archive_logs() {
    local log_dir="${1:?Log directory required}"
    local archive_dest="${2:-$log_dir/../archive}"
    
    if [[ ! -d "$log_dir" ]]; then
        log_warn "Log directory not found: $log_dir"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local archive_name="logs_${SLURM_JOB_ID:-local}_${timestamp}.tar.gz"
    
    ensure_directory "$archive_dest"
    
    log_info "Archiving logs to: $archive_dest/$archive_name"
    if tar -czf "$archive_dest/$archive_name" -C "$(dirname "$log_dir")" "$(basename "$log_dir")" 2>&1; then
        log_info "Log archive created successfully"
        return 0
    else
        log_error "Failed to create log archive"
        return 1
    fi
}

# Cleanup old log files
# Args:
#   $1: Log directory
#   $2: Days to keep (default: 30)
cleanup_old_logs() {
    local log_dir="${1:?Log directory required}"
    local days_to_keep="${2:-30}"
    
    if [[ ! -d "$log_dir" ]]; then
        log_warn "Log directory not found: $log_dir"
        return 1
    fi
    
    log_info "Cleaning up logs older than $days_to_keep days in: $log_dir"
    
    local count=$(find "$log_dir" -type f -mtime +$days_to_keep | wc -l)
    
    if [[ $count -gt 0 ]]; then
        log_info "Found $count old log files to remove"
        find "$log_dir" -type f -mtime +$days_to_keep -delete
        log_info "Old logs cleaned up"
    else
        log_info "No old logs to clean up"
    fi
}

# Save job metadata
# Args:
#   $1: Output file path
save_job_metadata() {
    local output_file="${1:?Output file required}"
    
    log_info "Saving job metadata to: $output_file"
    
    cat > "$output_file" <<EOF
{
  "job_id": "${SLURM_JOB_ID:-N/A}",
  "job_name": "${SLURM_JOB_NAME:-N/A}",
  "node": "${SLURM_NODELIST:-$(hostname)}",
  "user": "$USER",
  "start_time": "$(date -d @${SLURM_JOB_START_TIME:-$(date +%s)} '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')",
  "end_time": "$(date '+%Y-%m-%d %H:%M:%S')",
  "working_directory": "$(pwd)",
  "exit_code": "${1:-0}"
}
EOF
    
    log_info "Job metadata saved"
}

# Export functions
export -f register_cleanup
export -f execute_cleanup
export -f cleanup_files
export -f cleanup_temp_dir
export -f setup_cleanup_trap
export -f archive_logs
export -f cleanup_old_logs
export -f save_job_metadata

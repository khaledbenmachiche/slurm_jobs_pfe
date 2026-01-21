#!/bin/bash
#
# Monitor SLURM jobs
# Usage: monitor_jobs.sh [options]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common utilities
source "$PROJECT_ROOT/scripts/common/logging.sh"

usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Monitor SLURM jobs and view their status.

Options:
  -h, --help          Show this help message
  -u, --user USER     Show jobs for specific user (default: $USER)
  -j, --job JOB_ID    Show details for specific job ID
  -l, --logs JOB_ID   Show logs for specific job ID
  -w, --watch         Watch jobs in real-time (updates every 5 seconds)
  -a, --all           Show all jobs (including completed)

Examples:
  $(basename "$0")                    # Show your running jobs
  $(basename "$0") --watch            # Watch jobs in real-time
  $(basename "$0") --job 12345        # Show details for job 12345
  $(basename "$0") --logs 12345       # Show logs for job 12345

EOF
    exit 0
}

# Show job details
show_job_details() {
    local job_id="$1"
    
    log_info "Job details for: $job_id"
    log_separator "="
    
    if command -v scontrol &>/dev/null; then
        scontrol show job "$job_id"
    else
        log_error "scontrol command not found"
        exit 1
    fi
}

# Show job logs
show_job_logs() {
    local job_id="$1"
    local logs_dir="$PROJECT_ROOT/logs"
    
    log_info "Searching for logs of job: $job_id"
    log_separator "="
    
    # Find log files for this job
    local found=false
    
    for log_file in $(find "$logs_dir" -type f -name "*${job_id}*" 2>/dev/null); do
        found=true
        echo
        log_info "Log file: $log_file"
        log_separator "-"
        tail -n 50 "$log_file"
        log_separator "-"
    done
    
    if [[ "$found" == false ]]; then
        log_warn "No log files found for job $job_id in $logs_dir"
    fi
}

# Show jobs for user
show_jobs() {
    local user="$1"
    local show_all="$2"
    
    log_info "Jobs for user: $user"
    log_separator "="
    
    if command -v squeue &>/dev/null; then
        if [[ "$show_all" == true ]]; then
            squeue -u "$user" -o "%.18i %.9P %.30j %.8u %.8T %.10M %.9l %.6D %R"
        else
            squeue -u "$user" -t RUNNING,PENDING -o "%.18i %.9P %.30j %.8u %.8T %.10M %.9l %.6D %R"
        fi
    else
        log_error "squeue command not found"
        exit 1
    fi
    
    echo
    log_info "Job states: PD=Pending, R=Running, CG=Completing, CD=Completed"
}

# Watch jobs in real-time
watch_jobs() {
    local user="$1"
    
    log_info "Watching jobs for user: $user (press Ctrl+C to stop)"
    log_info "Updating every 5 seconds..."
    echo
    
    while true; do
        clear
        show_jobs "$user" false
        sleep 5
    done
}

# Main function
main() {
    local user="$USER"
    local job_id=""
    local show_logs=false
    local watch_mode=false
    local show_all=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -u|--user)
                user="$2"
                shift 2
                ;;
            -j|--job)
                job_id="$2"
                shift 2
                ;;
            -l|--logs)
                job_id="$2"
                show_logs=true
                shift 2
                ;;
            -w|--watch)
                watch_mode=true
                shift
                ;;
            -a|--all)
                show_all=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Execute requested action
    if [[ -n "$job_id" ]]; then
        if [[ "$show_logs" == true ]]; then
            show_job_logs "$job_id"
        else
            show_job_details "$job_id"
        fi
    elif [[ "$watch_mode" == true ]]; then
        watch_jobs "$user"
    else
        show_jobs "$user" "$show_all"
    fi
}

# Execute main function
main "$@"

#!/bin/bash
#
# Cancel SLURM jobs
# Usage: cancel_job.sh [options]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common utilities
source "$PROJECT_ROOT/scripts/common/logging.sh"

usage() {
    cat << EOF
Usage: $(basename "$0") <job_id> [options]

Cancel one or more SLURM jobs.

Arguments:
  job_id            Job ID to cancel (can specify multiple)

Options:
  -h, --help        Show this help message
  -a, --all         Cancel all your jobs
  -n, --name NAME   Cancel all jobs with specific name
  -f, --force       Force cancellation without confirmation

Examples:
  $(basename "$0") 12345
  $(basename "$0") 12345 12346 12347
  $(basename "$0") --name egraphs-dataset
  $(basename "$0") --all

EOF
    exit 0
}

# Cancel job by ID
cancel_job() {
    local job_id="$1"
    local force="$2"
    
    if [[ "$force" != true ]]; then
        read -p "Cancel job $job_id? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipped job $job_id"
            return 0
        fi
    fi
    
    log_info "Cancelling job: $job_id"
    if scancel "$job_id" 2>&1; then
        log_info "Job $job_id cancelled"
        return 0
    else
        log_error "Failed to cancel job $job_id"
        return 1
    fi
}

# Cancel all user jobs
cancel_all_jobs() {
    local user="$USER"
    local force="$1"
    
    log_warn "This will cancel ALL your running jobs"
    
    if [[ "$force" != true ]]; then
        read -p "Are you sure? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled operation"
            return 0
        fi
    fi
    
    log_info "Cancelling all jobs for user: $user"
    if scancel -u "$user" 2>&1; then
        log_info "All jobs cancelled"
    else
        log_error "Failed to cancel jobs"
        return 1
    fi
}

# Cancel jobs by name
cancel_jobs_by_name() {
    local job_name="$1"
    local force="$2"
    
    log_info "Finding jobs with name: $job_name"
    
    # Get job IDs with matching name
    local job_ids=$(squeue -u "$USER" -n "$job_name" -h -o "%i")
    
    if [[ -z "$job_ids" ]]; then
        log_warn "No jobs found with name: $job_name"
        return 0
    fi
    
    local count=$(echo "$job_ids" | wc -w)
    log_info "Found $count job(s) with name: $job_name"
    
    if [[ "$force" != true ]]; then
        echo "$job_ids"
        read -p "Cancel these jobs? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled operation"
            return 0
        fi
    fi
    
    for job_id in $job_ids; do
        cancel_job "$job_id" true
    done
}

# Main function
main() {
    local job_ids=()
    local cancel_all=false
    local job_name=""
    local force=false
    
    # Check if scancel is available
    if ! command -v scancel &>/dev/null; then
        log_error "scancel command not found"
        exit 1
    fi
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -a|--all)
                cancel_all=true
                shift
                ;;
            -n|--name)
                job_name="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                job_ids+=("$1")
                shift
                ;;
        esac
    done
    
    # Execute requested action
    if [[ "$cancel_all" == true ]]; then
        cancel_all_jobs "$force"
    elif [[ -n "$job_name" ]]; then
        cancel_jobs_by_name "$job_name" "$force"
    elif [[ ${#job_ids[@]} -gt 0 ]]; then
        for job_id in "${job_ids[@]}"; do
            cancel_job "$job_id" "$force"
        done
    else
        log_error "No job ID specified"
        echo
        usage
    fi
}

# Execute main function
main "$@"

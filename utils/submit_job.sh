#!/bin/bash
#
# Submit a SLURM job
# Usage: submit_job.sh <job_name>
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common utilities
source "$PROJECT_ROOT/scripts/common/logging.sh"

usage() {
    cat << EOF
Usage: $(basename "$0") <job_name> [options]

Submit a SLURM job from the jobs/ directory.

Arguments:
  job_name          Name of the job (without .sbatch extension)

Options:
  -h, --help        Show this help message
  -d, --dry-run     Show what would be submitted without actually submitting
  -l, --list        List available jobs

Examples:
  $(basename "$0") egraphs_dataset
  $(basename "$0") egraphs_dataset --dry-run
  $(basename "$0") --list

EOF
    exit 0
}

# List available jobs
list_jobs() {
    log_info "Available jobs:"
    echo
    
    local jobs_dir="$PROJECT_ROOT/jobs"
    
    if [[ ! -d "$jobs_dir" ]]; then
        log_error "Jobs directory not found: $jobs_dir"
        exit 1
    fi
    
    local count=0
    for job_file in "$jobs_dir"/*.sbatch; do
        if [[ -f "$job_file" ]]; then
            local job_name=$(basename "$job_file" .sbatch)
            echo "  - $job_name"
            ((count++))
        fi
    done
    
    echo
    log_info "Total jobs: $count"
    exit 0
}

# Main function
main() {
    local job_name=""
    local dry_run=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -l|--list)
                list_jobs
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                job_name="$1"
                shift
                ;;
        esac
    done
    
    # Validate job name
    if [[ -z "$job_name" ]]; then
        log_error "Job name is required"
        echo
        usage
    fi
    
    # Construct job file path
    local job_file="$PROJECT_ROOT/jobs/${job_name}.sbatch"
    
    # Check if job file exists
    if [[ ! -f "$job_file" ]]; then
        log_error "Job file not found: $job_file"
        echo
        log_info "Use --list to see available jobs"
        exit 1
    fi
    
    log_info "Job file: $job_file"
    
    # Show job details
    log_separator "-"
    log_info "Job configuration:"
    grep "^#SBATCH" "$job_file" | while read line; do
        echo "  $line"
    done
    log_separator "-"
    
    # Submit or dry-run
    if [[ "$dry_run" == true ]]; then
        log_info "DRY RUN: Would submit job with command:"
        echo "  sbatch $job_file"
        log_info "Use without --dry-run to actually submit"
    else
        log_info "Submitting job..."
        if sbatch "$job_file"; then
            log_info "Job submitted successfully"
        else
            log_error "Failed to submit job"
            exit 1
        fi
    fi
}

# Execute main function
main "$@"

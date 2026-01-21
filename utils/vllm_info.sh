#!/bin/bash
#
# Get vLLM server information
# Usage: vllm_info.sh [job_id]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common utilities
source "$PROJECT_ROOT/scripts/common/logging.sh"

usage() {
    cat << EOF
Usage: $(basename "$0") [job_id] [options]

Get information about running vLLM server.

Arguments:
  job_id            SLURM job ID (optional, will search for running vllm jobs)

Options:
  -h, --help        Show this help message
  -t, --test        Test server connection
  -p, --port PORT   Server port (default: 8000)

Examples:
  $(basename "$0")              # Find running vLLM server
  $(basename "$0") 12345        # Get info for specific job
  $(basename "$0") 12345 --test # Test server connection

EOF
    exit 0
}

# Find vLLM server job
find_vllm_job() {
    log_info "Searching for vLLM server jobs..."
    
    if ! command -v squeue &>/dev/null; then
        log_error "squeue command not found"
        return 1
    fi
    
    # Find running vllm-server jobs
    local jobs=$(squeue -u "$USER" -n "vllm-server" -t RUNNING -h -o "%i %N")
    
    if [[ -z "$jobs" ]]; then
        log_warn "No running vLLM server jobs found"
        return 1
    fi
    
    log_info "Found vLLM server job(s):"
    echo "$jobs" | while read job_id node; do
        echo "  Job ID: $job_id"
        echo "  Node: $node"
        echo
    done
    
    # Return first job ID
    echo "$jobs" | head -n1 | awk '{print $1}'
}

# Get job information
get_job_info() {
    local job_id="$1"
    
    log_info "Job information for: $job_id"
    log_separator "="
    
    if ! command -v scontrol &>/dev/null; then
        log_error "scontrol command not found"
        return 1
    fi
    
    # Get job details
    local job_info=$(scontrol show job "$job_id")
    
    # Extract key information
    local node=$(echo "$job_info" | grep -oP "NodeList=\K\S+")
    local state=$(echo "$job_info" | grep -oP "JobState=\K\S+")
    local partition=$(echo "$job_info" | grep -oP "Partition=\K\S+")
    
    echo "Job ID: $job_id"
    echo "State: $state"
    echo "Node: $node"
    echo "Partition: $partition"
    
    # Find PID file
    local logs_dir="$PROJECT_ROOT/logs/jobs/vllm_server"
    local pid_file=$(find "$logs_dir" -name "vllm_server.pid" -newer <(date -d '2 days ago' '+%Y%m%d') 2>/dev/null | head -n1)
    
    if [[ -n "$pid_file" && -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        echo "Process ID: $pid"
        echo "PID file: $pid_file"
    fi
    
    return 0
}

# Test server connection
test_server() {
    local job_id="$1"
    local port="${2:-8000}"
    
    log_info "Testing vLLM server connection..."
    
    # Get node from job
    local node=$(scontrol show job "$job_id" | grep -oP "NodeList=\K\S+")
    
    if [[ -z "$node" ]]; then
        log_error "Could not determine node for job $job_id"
        return 1
    fi
    
    log_info "Testing server at: http://${node}:${port}"
    
    # Test health endpoint
    if command -v curl &>/dev/null; then
        log_info "Testing /health endpoint..."
        if curl -s -m 5 "http://${node}:${port}/health" > /dev/null 2>&1; then
            log_info "✓ Server is responding"
            
            # Try to get version info
            log_info "Getting server info..."
            local response=$(curl -s -m 5 "http://${node}:${port}/version" 2>/dev/null || echo "{}")
            if [[ -n "$response" && "$response" != "{}" ]]; then
                echo "Response: $response"
            fi
            
            log_separator "-"
            log_info "Server URL: http://${node}:${port}"
            log_info "OpenAI-compatible endpoint: http://${node}:${port}/v1"
            log_separator "-"
            
            return 0
        else
            log_error "✗ Server is not responding"
            return 1
        fi
    else
        log_warn "curl not available, cannot test connection"
        log_info "Manually test with: curl http://${node}:${port}/health"
        return 1
    fi
}

# Main function
main() {
    local job_id=""
    local test_connection=false
    local port=8000
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -t|--test)
                test_connection=true
                shift
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                job_id="$1"
                shift
                ;;
        esac
    done
    
    # If no job ID provided, try to find one
    if [[ -z "$job_id" ]]; then
        job_id=$(find_vllm_job)
        if [[ -z "$job_id" ]]; then
            exit 1
        fi
    fi
    
    # Get job info
    get_job_info "$job_id"
    
    # Test connection if requested
    if [[ "$test_connection" == true ]]; then
        echo
        test_server "$job_id" "$port"
    fi
}

# Execute main function
main "$@"

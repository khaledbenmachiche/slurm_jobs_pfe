#!/bin/bash
#
# Job-specific script for egraphs dataset generation
# This script contains the core logic for the egraphs dataset job
#

set -e
set -o pipefail

# Get the absolute path to the scripts directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/env_setup.sh"
source "$SCRIPT_DIR/cleanup.sh"

# Job configuration
JOB_NAME="egraphs_dataset"
PROJECT_NAME="egraphs"

# Default configuration (can be overridden by config file or environment variables)
: ${PROJECT_DIR:="/scratch/$USER/chehab/egraphs"}
: ${INPUT_FILE:="/scratch/$USER/chehab/RL/fhe_rl/datasets/final_llm_dataset.txt"}
: ${OUTPUT_FILE:="traces.json"}
: ${DATASET_LIMIT:=10000}
: ${SEQUENCE_LENGTHS:="2,3,4"}
: ${WIDTHS:="4,8,16"}
: ${TIMEOUT:=600}
: ${NODE_LIMIT:=500000}

# Initialize logging
setup_job_logging "$JOB_NAME"
log_job_header "$JOB_NAME"

# Setup cleanup trap
setup_cleanup_trap

# Main job function
main() {
    # Setup temporary directory
    setup_temp_dir
    local tmp_input="$JOB_TEMP_DIR/llm_generated_veclangs_dataset_${SLURM_JOB_ID:-$$}.txt"
    register_cleanup "cleanup_files '$tmp_input'"
    
    # Load required modules
    log_info "Loading required modules..."
    load_modules gcc/9.2.0
    
    # Setup Rust environment
    setup_rust_env || {
        log_error "Failed to setup Rust environment"
        return 1
    }
    
    # Verify project directory
    verify_directory "$PROJECT_DIR" "Project directory" || return 1
    
    # Change to project directory
    log_info "Changing to project directory: $PROJECT_DIR"
    cd "$PROJECT_DIR" || {
        log_error "Failed to cd to $PROJECT_DIR"
        return 1
    }
    
    # Verify Cargo.toml exists
    verify_file "Cargo.toml" "Cargo.toml" || return 1
    
    # Verify input file
    verify_file "$INPUT_FILE" "Input file" || return 1
    local line_count=$(wc -l < "$INPUT_FILE")
    log_info "Input file contains $line_count lines"
    
    # Copy input to local /tmp for faster I/O
    log_info "Copying input file to temporary location for faster I/O..."
    log_duration "Input file copy" cp "$INPUT_FILE" "$tmp_input" || {
        log_error "Failed to copy input file"
        return 1
    }
    
    # Run the dataset generation
    log_separator "="
    log_info "Starting dataset generation with cargo..."
    log_info "Configuration:"
    log_info "  Input: $tmp_input"
    log_info "  Output: $OUTPUT_FILE"
    log_info "  Limit: $DATASET_LIMIT"
    log_info "  Sequences: $SEQUENCE_LENGTHS"
    log_info "  Widths: $WIDTHS"
    log_info "  Timeout: $TIMEOUT"
    log_info "  Node limit: $NODE_LIMIT"
    log_separator "="
    
    if log_duration "Dataset generation" \
        cargo run --release --bin generate_dataset -- \
            --input "$tmp_input" \
            --output "$OUTPUT_FILE" \
            --limit "$DATASET_LIMIT" \
            --sequence "$SEQUENCE_LENGTHS" \
            --widths "$WIDTHS" \
            --timeout "$TIMEOUT" \
            --node-limit "$NODE_LIMIT"; then
        
        log_info "Dataset generation completed successfully"
        
        # Verify output file
        if verify_file "$OUTPUT_FILE" "Output file"; then
            local output_size=$(du -h "$OUTPUT_FILE" | cut -f1)
            log_info "Output file size: $output_size"
            
            # Count entries if it's a JSON file
            if command -v jq &>/dev/null; then
                local entry_count=$(jq '. | length' "$OUTPUT_FILE" 2>/dev/null || echo "unknown")
                log_info "Output entries: $entry_count"
            fi
        else
            log_warn "Output file not found after generation"
            return 1
        fi
    else
        log_error "Dataset generation failed"
        return 1
    fi
    
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

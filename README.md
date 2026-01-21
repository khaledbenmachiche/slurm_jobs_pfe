# SLURM Jobs Management System

A well-structured project for managing multiple SLURM batch jobs with modular scripts, organized logging, and easy-to-use utilities.

## 📁 Project Structure

```
slurm_jobs/
├── README.md                          # This file
├── .gitignore                         # Git ignore rules
├── jobs/                              # SLURM batch job definitions
│   └── egraphs_dataset.sbatch        # Example job
├── scripts/                           # Job scripts and utilities
│   ├── common/                        # Reusable modules
│   │   ├── logging.sh                # Logging utilities
│   │   ├── env_setup.sh              # Environment setup
│   │   └── cleanup.sh                # Cleanup utilities
│   └── job_specific/                  # Job-specific logic
│       └── egraphs_dataset.sh        # Egraphs dataset job logic
├── configs/                           # Job configuration files
│   └── egraphs_dataset.conf          # Egraphs dataset config
├── logs/                              # Structured log output
│   ├── jobs/                          # Job-level logs
│   └── scripts/                       # Script-level logs
└── utils/                             # Management utilities
    ├── submit_job.sh                 # Submit jobs
    ├── monitor_jobs.sh               # Monitor jobs
    └── cancel_job.sh                 # Cancel jobs
```

## 🚀 Quick Start

### Submit a Job

```bash
# Submit the egraphs dataset job
./utils/submit_job.sh egraphs_dataset

# Dry-run to see what would be submitted
./utils/submit_job.sh egraphs_dataset --dry-run

# List all available jobs
./utils/submit_job.sh --list
```

### Monitor Jobs

```bash
# Show your running jobs
./utils/monitor_jobs.sh

# Watch jobs in real-time (updates every 5 seconds)
./utils/monitor_jobs.sh --watch

# Show details for a specific job
./utils/monitor_jobs.sh --job 12345

# Show logs for a specific job
./utils/monitor_jobs.sh --logs 12345

# Show all jobs (including completed)
./utils/monitor_jobs.sh --all
```

### Cancel Jobs

```bash
# Cancel a specific job
./utils/cancel_job.sh 12345

# Cancel multiple jobs
./utils/cancel_job.sh 12345 12346 12347

# Cancel all jobs with a specific name
./utils/cancel_job.sh --name egraphs-dataset

# Cancel all your jobs (with confirmation)
./utils/cancel_job.sh --all

# Force cancel without confirmation
./utils/cancel_job.sh 12345 --force
```

## 📝 Creating a New Job

### 1. Create the Job-Specific Script

Create a new script in `scripts/job_specific/` that contains your job logic:

```bash
# scripts/job_specific/my_new_job.sh
#!/bin/bash

set -e
set -o pipefail

# Get scripts directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/env_setup.sh"
source "$SCRIPT_DIR/cleanup.sh"

# Job configuration
JOB_NAME="my_new_job"

# Initialize logging
setup_job_logging "$JOB_NAME"
log_job_header "$JOB_NAME"

# Setup cleanup trap
setup_cleanup_trap

# Main job function
main() {
    log_info "Starting my new job..."
    
    # Your job logic here
    
    log_info "Job completed successfully"
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
```

### 2. Create the SBATCH File

Create a new SBATCH file in `jobs/`:

```bash
# jobs/my_new_job.sbatch
#!/bin/bash
#SBATCH --job-name=my-new-job
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16GB
#SBATCH --time=1-00:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your-email@example.com

# Get project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the job-specific script
JOB_SCRIPT="$PROJECT_ROOT/scripts/job_specific/my_new_job.sh"

if [[ ! -f "$JOB_SCRIPT" ]]; then
    echo "ERROR: Job script not found: $JOB_SCRIPT"
    exit 1
fi

# Optional: Load configuration
CONFIG_FILE="$PROJECT_ROOT/configs/my_new_job.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Execute the job script
bash "$JOB_SCRIPT"
```

### 3. (Optional) Create a Configuration File

Create a configuration file in `configs/` to override default values:

```bash
# configs/my_new_job.conf

# Override default configuration
VARIABLE_1="value1"
VARIABLE_2="value2"

# Logging level (0=DEBUG, 1=INFO, 2=WARN, 3=ERROR)
LOG_LEVEL=1
```

### 4. Make Scripts Executable

```bash
chmod +x scripts/job_specific/my_new_job.sh
chmod +x jobs/my_new_job.sbatch
```

### 5. Submit Your Job

```bash
./utils/submit_job.sh my_new_job
```

## 📊 Logging System

### Structured Logging

The logging system provides structured, consistent logs with different levels:

- **DEBUG**: Detailed debugging information
- **INFO**: General informational messages
- **WARN**: Warning messages
- **ERROR**: Error messages

### Log Locations

Logs are organized by type:

```
logs/
├── jobs/
│   └── egraphs_dataset/
│       ├── job_12345_20260121_143022.log
│       └── job_12345_20260121_143022.err
└── scripts/
    └── egraphs_dataset/
        └── script_20260121_143022.log
```

### Using the Logging Functions

```bash
# Basic logging
log_info "This is an info message"
log_warn "This is a warning"
log_error "This is an error"
log_debug "This is debug info"

# Log with duration measurement
log_duration "Data processing" process_data input.txt output.txt

# Log file operations
log_file_op "created" "/path/to/file.txt"

# Log command execution
log_command "Running analysis script"

# Log separators for better readability
log_separator "="
log_separator "-" 40
```

### Setting Log Level

Control logging verbosity by setting the `LOG_LEVEL` environment variable:

```bash
# In your config file or job script
export LOG_LEVEL=0  # DEBUG - show everything
export LOG_LEVEL=1  # INFO - show info and above (default)
export LOG_LEVEL=2  # WARN - show warnings and errors only
export LOG_LEVEL=3  # ERROR - show errors only
```

## 🔧 Common Utilities

### Environment Setup (`env_setup.sh`)

```bash
# Load modules
load_modules gcc/9.2.0 python/3.9

# Setup Rust environment
setup_rust_env

# Setup Python virtual environment
setup_python_env /path/to/venv

# Setup Conda environment
setup_conda_env my_env

# Verify commands exist
verify_command cargo
verify_file /path/to/input.txt "Input file"
verify_directory /path/to/dir "Project directory"

# Create directories
ensure_directory /path/to/dir
setup_scratch_dir my_project
setup_temp_dir

# Print environment summary
print_env_summary
```

### Cleanup (`cleanup.sh`)

```bash
# Register cleanup tasks (executed on exit)
register_cleanup "rm -f /tmp/tempfile.txt"
register_cleanup "cleanup_files /tmp/file1 /tmp/file2"

# Setup automatic cleanup on exit
setup_cleanup_trap

# Cleanup temporary files
cleanup_files /tmp/file1.txt /tmp/file2.txt

# Cleanup temporary directory
cleanup_temp_dir

# Archive logs
archive_logs /path/to/logs /path/to/archive

# Cleanup old logs (older than 30 days)
cleanup_old_logs /path/to/logs 30
```

## 📋 Configuration Management

Each job can have a configuration file in `configs/` that overrides default values:

```bash
# configs/egraphs_dataset.conf

# Project paths
PROJECT_DIR="/scratch/$USER/my_project"
INPUT_FILE="/path/to/input.txt"
OUTPUT_FILE="output.json"

# Job parameters
DATASET_LIMIT=10000
TIMEOUT=600

# Logging
LOG_LEVEL=1
```

Configuration files are automatically sourced if they exist, allowing you to:
- Keep sensitive paths out of git
- Easily switch between different configurations
- Override defaults without modifying scripts

## 🎯 Best Practices

### 1. **Modularity**
- Keep common functionality in `scripts/common/`
- Put job-specific logic in `scripts/job_specific/`
- Use configuration files for parameters that change

### 2. **Error Handling**
- Use `set -e` to exit on errors
- Use `set -o pipefail` to catch errors in pipelines
- Validate inputs before processing
- Use cleanup traps to ensure cleanup happens

### 3. **Logging**
- Log important operations and their results
- Use appropriate log levels
- Include timing information for long operations
- Log both to files and console

### 4. **Resource Management**
- Clean up temporary files in trap handlers
- Use local `/tmp` for I/O-intensive operations
- Archive or rotate old logs periodically

### 5. **Version Control**
- Commit job definitions and scripts
- Don't commit logs or temporary files (use .gitignore)
- Don't commit sensitive information (use config files)

## 📚 Examples

### Example: Data Processing Job

```bash
# scripts/job_specific/process_data.sh
main() {
    # Setup environment
    load_modules python/3.9
    setup_python_env /path/to/venv
    
    # Verify inputs
    verify_file "$INPUT_FILE" "Input dataset"
    verify_command python
    
    # Setup temp directory
    setup_temp_dir
    register_cleanup cleanup_temp_dir
    
    # Process data
    log_duration "Data processing" \
        python process.py --input "$INPUT_FILE" --output "$OUTPUT_FILE"
    
    # Verify output
    verify_file "$OUTPUT_FILE" "Processed output"
    
    return 0
}
```

### Example: Multi-Stage Pipeline

```bash
main() {
    # Stage 1: Preprocessing
    log_separator "="
    log_info "Stage 1: Preprocessing"
    log_separator "="
    
    if log_duration "Preprocessing" ./preprocess.sh; then
        log_info "Preprocessing completed"
    else
        log_error "Preprocessing failed"
        return 1
    fi
    
    # Stage 2: Main processing
    log_separator "="
    log_info "Stage 2: Main processing"
    log_separator "="
    
    if log_duration "Main processing" ./process.sh; then
        log_info "Main processing completed"
    else
        log_error "Main processing failed"
        return 1
    fi
    
    # Stage 3: Postprocessing
    log_separator "="
    log_info "Stage 3: Postprocessing"
    log_separator "="
    
    if log_duration "Postprocessing" ./postprocess.sh; then
        log_info "Postprocessing completed"
    else
        log_error "Postprocessing failed"
        return 1
    fi
    
    return 0
}
```

## 🐛 Troubleshooting

### Job Not Starting
- Check SLURM queue: `./utils/monitor_jobs.sh`
- Verify resource requirements in SBATCH file
- Check partition and QOS settings

### Job Failed
- Check logs in `logs/jobs/<job_name>/`
- Look at error logs: `./utils/monitor_jobs.sh --logs JOB_ID`
- Verify input files exist and are accessible

### Module Not Found
- Check if module is available: `module avail`
- Verify module name in job script
- Check if module is loaded correctly

### Permission Denied
- Verify scripts are executable: `chmod +x script.sh`
- Check file/directory permissions
- Verify you have access to scratch directories

## 🤝 Contributing

When adding new jobs:
1. Follow the structure in existing jobs
2. Use the common utilities for consistency
3. Add appropriate logging
4. Test with `--dry-run` first
5. Document any special requirements

## 📄 License

This project structure is free to use and modify for your SLURM job management needs.

---

**Need help?** Check the utility scripts with `--help`:
```bash
./utils/submit_job.sh --help
./utils/monitor_jobs.sh --help
./utils/cancel_job.sh --help
```

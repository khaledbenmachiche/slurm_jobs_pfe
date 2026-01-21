# vLLM Server Job

Runs a vLLM inference server with GPU support for serving large language models.

## Quick Start

```bash
# Submit the vLLM server job
./utils/submit_job.sh vllm_server

# Check server status
./utils/vllm_info.sh

# Test server connection
./utils/vllm_info.sh --test

# Monitor the job
./utils/monitor_jobs.sh --watch
```

## Configuration

Edit `configs/vllm_server.conf` to customize:

```bash
# Model configuration
MODEL_PATH="/scratch/kb5253/models/Qwen2.5-32B-Instruct"
DTYPE="auto"
MAX_MODEL_LEN=8192
GPU_MEMORY_UTILIZATION=0.9

# Server configuration
HOST="0.0.0.0"
PORT=8000

# HuggingFace cache
HF_CACHE_DIR="/scratch/kb5253/hf_cache"
```

## Resource Requirements

- **GPU**: 1x A100
- **Memory**: 64GB
- **CPUs**: 8
- **Time**: 2 days (adjustable)
- **Partition**: nvidia
- **QOS**: c2

## Using the Server

Once the server is running, you can access it via:

### Health Check

```bash
curl http://<node>:8000/health
```

### OpenAI-Compatible API

```bash
curl http://<node>:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2.5-32B-Instruct",
    "prompt": "Hello, how are you?",
    "max_tokens": 100
  }'
```

### Using with OpenAI Client

```python
from openai import OpenAI

# Get the node from: ./utils/vllm_info.sh
client = OpenAI(
    base_url="http://<node>:8000/v1",
    api_key="dummy"  # vLLM doesn't require authentication by default
)

completion = client.completions.create(
    model="Qwen2.5-32B-Instruct",
    prompt="Hello, how are you?"
)

print(completion.choices[0].text)
```

## Getting Server Information

```bash
# Find running vLLM server and show info
./utils/vllm_info.sh

# Show info for specific job
./utils/vllm_info.sh 12345

# Test server connection
./utils/vllm_info.sh 12345 --test
```

## Logs

Logs are stored in:

```
logs/jobs/vllm_server/
├── job_<JOB_ID>_<TIMESTAMP>.log
├── job_<JOB_ID>_<TIMESTAMP>.err
└── vllm_server.pid
```

## Environment Variables

The job automatically sets:

- `HF_HOME` - HuggingFace cache directory
- `TRANSFORMERS_CACHE` - Transformers cache
- `HF_DATASETS_CACHE` - Datasets cache

## Troubleshooting

### Server not starting

```bash
# Check logs
./utils/monitor_jobs.sh --logs <JOB_ID>

# Verify GPU is available
squeue -u $USER -o "%.18i %.9P %.30j %.8T %.10M %.6D %b"
```

### Connection refused

- Ensure you're connecting from the same cluster
- Check firewall rules
- Verify the port is not blocked

### Out of memory

- Reduce `MAX_MODEL_LEN`
- Reduce `GPU_MEMORY_UTILIZATION`
- Use a smaller model

### Model not found

- Verify `MODEL_PATH` exists
- Check model files are complete
- Ensure proper permissions

## Stopping the Server

```bash
# Cancel the job (this will gracefully stop the server)
./utils/cancel_job.sh <JOB_ID>
```

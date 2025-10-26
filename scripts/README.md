# Automation Scripts

## runpod_build_automation.py

Automated Docker build on RunPod via API.

### Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Set up environment
export RUNPOD_API_KEY="your-key-from-runpod"
export GITHUB_REPOSITORY="babushkai/receipt-tracker-ios"
export GITHUB_TOKEN="your-github-token"

# Run
python3 runpod_build_automation.py
```

### What It Does

1. Creates RunPod GPU pod (RTX 4000 Ada spot)
2. Waits for pod to be ready
3. SSHs in automatically  
4. Clones your repo
5. Builds Docker image
6. Pushes to ghcr.io
7. Terminates pod
8. **Cost**: ~$0.01 per build

### GitHub Actions Integration

This script is used by `.github/workflows/build-on-runpod-automated.yml` for fully automated builds.

See [RUNPOD_API_SETUP.md](../RUNPOD_API_SETUP.md) for setup instructions.


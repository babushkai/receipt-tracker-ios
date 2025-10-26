# Docker Quick Start Guide

## ⚠️ Important: macOS Users

**vLLM cannot be built on macOS** (especially Apple Silicon). You must build on Linux x86_64.

**👉 See [BUILD_ON_RUNPOD.md](BUILD_ON_RUNPOD.md) for detailed build instructions!**

---

## Option 1: Pull Pre-built Image from Docker Hub

```bash
# Replace with your actual Docker Hub username once you've pushed
docker pull your-dockerhub-username/deepseek-ocr-server:latest

# Run locally (requires Linux + NVIDIA GPU)
docker run --gpus all -p 5003:5003 your-dockerhub-username/deepseek-ocr-server:latest
```

## Option 2: Build on RunPod (Recommended)

```bash
# 1. Build the image
docker build -f Dockerfile.deepseek -t deepseek-ocr-server:latest .

# 2. Run locally with GPU
docker run --gpus all -p 5003:5003 deepseek-ocr-server:latest

# 3. Or use docker-compose
docker-compose up
```

## Option 3: Build and Push to Your Docker Hub

```bash
# 1. Set your Docker Hub username
export DOCKER_USERNAME="your-dockerhub-username"

# 2. Run the build script
./build_and_push.sh

# 3. Follow prompts to push to Docker Hub
```

## Deploy to RunPod

Once your image is on Docker Hub:

1. **Create Template** in RunPod dashboard
   - Image: `your-dockerhub-username/deepseek-ocr-server:latest`
   - Container Disk: 20GB
   - Expose Port: 5003

2. **Deploy Pod**
   - GPU: RTX 4090, A5000, or A6000 (24GB+ VRAM)
   - Wait 5-10 minutes for first-time model download

3. **Test Connection**
   ```bash
   curl http://<pod-ip>:<port>/health
   ```

4. **Configure iOS App**
   - Settings → DeepSeek-OCR URL: `http://<pod-ip>:<port>`

## Test Locally

```bash
# Health check
curl http://localhost:5003/health

# OCR test (requires base64-encoded image)
python3 test_deepseek_image.py
```

## What's Inside

- **Base Image**: NVIDIA CUDA 12.1 + Ubuntu 22.04
- **Python**: 3.10
- **Key Dependencies**:
  - vLLM (nightly build) for optimized inference
  - Flask for REST API
  - Pillow for image processing
- **Model**: deepseek-ai/DeepSeek-OCR (~8GB download on first run)

## Resource Requirements

- **GPU**: 24GB+ VRAM (RTX 3090, 4090, A5000, A6000)
- **Disk**: 20GB+ (for vLLM, model cache, and kernels)
- **RAM**: 16GB+ recommended
- **OS**: Linux with NVIDIA drivers (Docker host)

## Cost on RunPod

- **RTX 4090**: ~$0.25/hour (spot) or ~$0.44/hour (on-demand)
- **A5000**: ~$0.19/hour (spot) or ~$0.34/hour (on-demand)

For 100 receipts/month: ~$0.25-$0.50 🎉

## Troubleshooting

**Container exits immediately**: Check GPU with `nvidia-smi`  
**Out of memory**: Use GPU with 24GB+ VRAM  
**Model download slow**: First run downloads 8GB, be patient  
**Port not accessible**: Check RunPod port forwarding settings

## Full Documentation

See [RUNPOD_DEPLOYMENT.md](RUNPOD_DEPLOYMENT.md) for detailed instructions.


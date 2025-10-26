# DeepSeek-OCR RunPod Deployment Guide

This guide explains how to deploy the DeepSeek-OCR server with vLLM on RunPod using Docker.

## Quick Start (Using Pre-built Image)

If you've already built and pushed the Docker image to Docker Hub:

### 1. Create RunPod Template

1. Go to [RunPod.io](https://www.runpod.io/) and sign in
2. Navigate to **Templates** → **New Template**
3. Configure:
   - **Template Name**: `DeepSeek-OCR vLLM`
   - **Container Image**: `your-dockerhub-username/deepseek-ocr-server:latest`
   - **Container Disk**: `20 GB` (for vLLM and model cache)
   - **Expose HTTP Ports**: `5003`
   - **Expose TCP Ports**: (leave empty)

### 2. Deploy Pod

1. Go to **Pods** → **GPU Pods** → **Deploy**
2. Select your template: `DeepSeek-OCR vLLM`
3. Choose GPU:
   - **Recommended**: RTX 4090, A5000, A6000 (24GB+ VRAM)
   - **Budget**: RTX 3090 (24GB) works but slower
4. Click **Deploy On-Demand** or **Deploy Spot** (cheaper but can be interrupted)

### 3. Connect to Your Server

Once the pod is running:

1. Find your pod's public IP and port
2. The server will be available at: `http://<pod-ip>:<port>`
3. Test with: `curl http://<pod-ip>:<port>/health`

### 4. Configure iOS App

In your Receipt Tracker iOS app:
1. Go to **Settings**
2. Set **DeepSeek-OCR Server URL** to: `http://<pod-ip>:<port>`
3. Test the connection
4. Start scanning receipts!

---

## Building and Pushing Your Own Image

If you want to build and push the image yourself:

### 1. Build the Docker Image

```bash
# Set your Docker Hub username
export DOCKER_USERNAME="your-dockerhub-username"

# Build and optionally push
./build_and_push.sh
```

Or manually:

```bash
docker build -f Dockerfile.deepseek -t your-dockerhub-username/deepseek-ocr-server:latest .
docker push your-dockerhub-username/deepseek-ocr-server:latest
```

### 2. Test Locally (with GPU)

```bash
# Using docker-compose (recommended)
docker-compose up

# Or directly
docker run --gpus all -p 5003:5003 your-dockerhub-username/deepseek-ocr-server:latest
```

### 3. Deploy to RunPod

Follow the "Quick Start" steps above, using your image name.

---

## Cost Estimation

RunPod pricing (as of 2025):
- **RTX 4090** (24GB): ~$0.44/hour on-demand, ~$0.25/hour spot
- **A5000** (24GB): ~$0.34/hour on-demand, ~$0.19/hour spot
- **A6000** (48GB): ~$0.79/hour on-demand, ~$0.44/hour spot

For occasional use:
- 10 hours/month: ~$2.50-$4.40/month
- 100 receipts: ~$0.25-$0.50 (assuming 1-2 minutes per batch)

💡 **Tip**: Use **Spot Instances** for 40-50% savings!

---

## API Endpoints

### Health Check
```bash
curl http://<server-url>/health
```

### Single Image OCR
```bash
curl -X POST http://<server-url>/ocr \
  -H "Content-Type: application/json" \
  -d '{
    "image": "<base64-encoded-image>",
    "prompt": "Free OCR."
  }'
```

### Batch OCR (Recommended for Multiple Receipts)
```bash
curl -X POST http://<server-url>/ocr/batch \
  -H "Content-Type: application/json" \
  -d '{
    "images": ["<base64-1>", "<base64-2>", ...],
    "prompt": "Free OCR."
  }'
```

---

## Troubleshooting

### Pod Won't Start
- **Check GPU**: Ensure you selected a GPU with 24GB+ VRAM
- **Check Disk Space**: Increase container disk to 25GB+
- **View Logs**: In RunPod dashboard, click pod → Logs

### Model Loading Takes Forever
- First run downloads ~8GB model from Hugging Face
- This takes 5-10 minutes depending on RunPod's connection
- Subsequent starts are much faster (model is cached)

### Out of Memory
- DeepSeek-OCR requires ~16-20GB VRAM
- Use GPU with 24GB+ VRAM
- Reduce batch size in requests

### Connection Timeout
- vLLM compiles CUDA kernels on first inference (2-3 minutes)
- Wait a bit longer and try again
- Check pod logs for errors

---

## Advanced Configuration

### Custom Environment Variables

Edit `Dockerfile.deepseek` to add:

```dockerfile
ENV VLLM_USE_MODELSCOPE=False
ENV HF_HOME=/app/.cache/huggingface
ENV CUDA_VISIBLE_DEVICES=0
```

### Enable Persistent Storage

In RunPod template settings:
- Add **Network Volume** for model cache
- Mount at `/root/.cache/huggingface`
- Saves model downloads across pod restarts

### Multiple Workers (Not Recommended)

vLLM manages GPU memory efficiently for batch processing. Multiple workers usually don't help and can cause OOM errors.

---

## Monitoring

### Check Resource Usage

```bash
# SSH into pod
nvidia-smi  # Check GPU usage
htop        # Check CPU/RAM
```

### View Logs

```bash
# In RunPod dashboard
Pod → Logs

# Or via SSH
docker logs -f <container-id>
```

---

## Security Notes

⚠️ **Important**:
- The server has **NO authentication** by default
- Don't expose it to the public internet without adding auth
- Use RunPod's firewall to restrict access
- Consider adding API key authentication for production use

---

## Next Steps

1. ✅ Build and push Docker image
2. ✅ Create RunPod template
3. ✅ Deploy pod
4. ✅ Test with curl
5. ✅ Configure iOS app
6. ✅ Start scanning receipts!

🎉 Enjoy state-of-the-art OCR with DeepSeek-OCR + vLLM!

---

## References

- [vLLM DeepSeek-OCR Guide](https://docs.vllm.ai/projects/recipes/en/latest/DeepSeek/DeepSeek-OCR.html)
- [RunPod Documentation](https://docs.runpod.io/)
- [DeepSeek-OCR Model Card](https://huggingface.co/deepseek-ai/DeepSeek-OCR)



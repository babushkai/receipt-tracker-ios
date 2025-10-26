# Build on Your RunPod Server

## Your RunPod Specs ✅
- **GPU**: RTX 4000 Ada (20GB VRAM) ✅ Should work!
- **vCPU**: 16 cores
- **Memory**: 62 GB
- **Container Disk**: 30 GB
- **Volume**: 50 GB at `/workspace`
- **Template**: runpod-torch-v280 (PyTorch pre-installed)

---

## Quick Build Steps

### 1. Connect to Your RunPod Instance

In RunPod dashboard:
- Click your pod → **Connect** → **Start Web Terminal**
- Or use SSH if you prefer

### 2. Upload Your Files

**Option A: Using Git (Recommended)**
```bash
cd /workspace
git clone https://github.com/your-username/receipt.git
cd receipt
```

**Option B: Manual Upload**
```bash
cd /workspace
mkdir deepseek-build
cd deepseek-build

# Create the server file
cat > deepseek_ocr_server.py << 'EOF'
# Paste your entire deepseek_ocr_server.py content here
EOF

# Create the Dockerfile
cat > Dockerfile.deepseek.prebuilt << 'EOF'
FROM vllm/vllm-openai:latest
RUN pip install --no-cache-dir flask pillow
WORKDIR /app
COPY deepseek_ocr_server.py /app/
EXPOSE 5003
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5003/health || exit 1
CMD ["python", "deepseek_ocr_server.py"]
EOF
```

### 3. Build the Docker Image

```bash
# Using the pre-built vLLM base (FASTEST - 2-3 minutes)
docker build -f Dockerfile.deepseek.prebuilt -t deepseek-ocr-server:latest .

# Or if you prefer full build (10-15 minutes)
docker build -f Dockerfile.deepseek -t deepseek-ocr-server:latest .
```

### 4. Tag for Docker Hub

```bash
# Replace with YOUR Docker Hub username
export DOCKER_USERNAME="your-dockerhub-username"

docker tag deepseek-ocr-server:latest ${DOCKER_USERNAME}/deepseek-ocr-server:latest
```

### 5. Login and Push

```bash
# Login to Docker Hub
docker login
# Enter your username and password

# Push the image
docker push ${DOCKER_USERNAME}/deepseek-ocr-server:latest
```

---

## One-Liner Build Script

Copy and paste this entire block:

```bash
cd /workspace && \
export DOCKER_USERNAME="YOUR_DOCKERHUB_USERNAME" && \
echo "Building DeepSeek-OCR with pre-built vLLM..." && \
docker build -f Dockerfile.deepseek.prebuilt -t ${DOCKER_USERNAME}/deepseek-ocr-server:latest . && \
echo "Build successful! Tagging..." && \
docker tag ${DOCKER_USERNAME}/deepseek-ocr-server:latest ${DOCKER_USERNAME}/deepseek-ocr-server:latest && \
echo "Logging in to Docker Hub..." && \
docker login && \
echo "Pushing to Docker Hub..." && \
docker push ${DOCKER_USERNAME}/deepseek-ocr-server:latest && \
echo "✅ Done! Image pushed successfully!"
```

---

## Test Before Pushing (Optional)

```bash
# Run locally on your RunPod instance
docker run --gpus all -p 5003:5003 deepseek-ocr-server:latest &

# Wait 30 seconds for model to load, then test
sleep 30
curl http://localhost:5003/health

# If it works, stop the container and push to Docker Hub
docker ps  # Find container ID
docker stop <container-id>
```

---

## Deploy to Another RunPod Instance

Once pushed to Docker Hub:

1. **Stop your build pod** (save costs)
2. **Create new template**:
   - Docker Image: `your-dockerhub-username/deepseek-ocr-server:latest`
   - Container Disk: 20 GB
   - Expose HTTP Port: 5003
3. **Deploy production pod**:
   - Use this template
   - Choose RTX 4090/A5000 for best performance
   - Or RTX 4000 Ada if you want to keep costs lower

---

## Performance Notes: RTX 4000 Ada

Your RTX 4000 Ada has **20GB VRAM**:
- ✅ Should work for DeepSeek-OCR
- ⚠️ May be slower than RTX 4090 (24GB)
- ⚠️ May have limited batch size
- 💡 If you get OOM errors, upgrade to RTX 4090 or A5000

---

## Cost Comparison

**Your current build server** (RTX 4000 Ada):
- $0.27/hour
- Use for building only (stop when done)
- Build time: ~3 minutes = **~$0.01**

**Production server options**:
- RTX 4000 Ada: $0.27/hour (your current, works but slower)
- RTX 4090: $0.25/hour spot, $0.44/hour on-demand (faster, 24GB)
- A5000: $0.19/hour spot, $0.34/hour on-demand (best value!)

💡 **Recommendation**: Build on RTX 4000 Ada, deploy on **A5000 spot** for best value!

---

## Troubleshooting

**Docker not found**: `apt update && apt install docker.io`

**Permission denied**: `sudo usermod -aG docker $USER` then logout/login

**Build fails**: Make sure you're in the directory with Dockerfile

**Out of disk space**: Clean up: `docker system prune -a`

---

## After Building

Your image will be at:
- **Docker Hub**: `your-dockerhub-username/deepseek-ocr-server:latest`
- **Size**: ~8-10 GB
- **Ready to deploy**: On any RunPod GPU instance!

🎉 Now you can deploy this image on multiple RunPod instances without rebuilding!



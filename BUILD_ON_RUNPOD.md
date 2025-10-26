# Building DeepSeek-OCR Docker Image on RunPod

Since vLLM only supports x86_64 Linux (not macOS or ARM), you have several options:

## ⭐ Option 1: Build Directly on RunPod (Recommended)

This is the easiest approach - build the image directly on a RunPod GPU instance.

### Step 1: Start a RunPod Instance

1. Go to [RunPod.io](https://www.runpod.io/)
2. Deploy a **GPU Pod** (any GPU works for building, even cheap ones)
3. Select template: **RunPod PyTorch** or **RunPod Ubuntu**
4. Enable **SSH** access

### Step 2: Upload Your Code

```bash
# From your Mac, copy files to RunPod
# First, get your RunPod SSH details from the pod dashboard

# Upload the necessary files
scp deepseek_ocr_server.py root@<pod-ip>:/workspace/
scp Dockerfile.deepseek root@<pod-ip>:/workspace/
scp .dockerignore root@<pod-ip>:/workspace/
```

Or use the RunPod web terminal (easier):

1. Open pod → **Connect** → **Start Web Terminal**
2. In the terminal:

```bash
cd /workspace

# Create deepseek_ocr_server.py
nano deepseek_ocr_server.py
# Paste your code, Ctrl+O to save, Ctrl+X to exit

# Create Dockerfile.deepseek
nano Dockerfile.deepseek
# Paste your Dockerfile, Ctrl+O to save, Ctrl+X to exit
```

### Step 3: Build on RunPod

```bash
# In the RunPod terminal
cd /workspace

# Build the image
docker build -f Dockerfile.deepseek -t deepseek-ocr-server:latest .

# Tag for Docker Hub
docker tag deepseek-ocr-server:latest your-dockerhub-username/deepseek-ocr-server:latest

# Login to Docker Hub
docker login
# Enter your Docker Hub username and password

# Push to Docker Hub
docker push your-dockerhub-username/deepseek-ocr-server:latest
```

### Step 4: Deploy from Docker Hub

Now you can deploy on any RunPod instance using your Docker Hub image!

---

## Option 2: Use Pre-built vLLM Image (Fastest!)

Instead of building from scratch, extend the official vLLM image:

### Updated Dockerfile (Simpler!)

Create `Dockerfile.deepseek.prebuilt`:

```dockerfile
# Use official vLLM image as base (already has everything!)
FROM vllm/vllm-openai:latest

# Install Flask for our REST API
RUN pip install flask

# Copy server code
WORKDIR /app
COPY deepseek_ocr_server.py /app/

# Expose port
EXPOSE 5003

# Run server
CMD ["python", "deepseek_ocr_server.py"]
```

Build this on RunPod:

```bash
docker build -f Dockerfile.deepseek.prebuilt -t your-dockerhub-username/deepseek-ocr-server:latest .
docker push your-dockerhub-username/deepseek-ocr-server:latest
```

---

## Option 3: Use Docker Buildx with Remote Builder

Build from your Mac using a remote Linux builder:

```bash
# Create a remote builder (requires a Linux machine or cloud VM)
docker buildx create --name remote-builder --driver docker-container --use

# Build for x86_64 Linux
docker buildx build \
  --platform linux/amd64 \
  -f Dockerfile.deepseek \
  -t your-dockerhub-username/deepseek-ocr-server:latest \
  --push \
  .
```

This still requires access to a Linux x86_64 machine or using Docker Desktop's cloud build features.

---

## Option 4: Use GitHub Actions (Automated)

Set up GitHub Actions to build automatically on every commit.

Create `.github/workflows/docker-build.yml`:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
    
    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        context: .
        file: ./Dockerfile.deepseek
        push: true
        tags: ${{ secrets.DOCKER_USERNAME }}/deepseek-ocr-server:latest
```

Add secrets to your GitHub repo:
- `DOCKER_USERNAME`
- `DOCKER_PASSWORD`

---

## 🎯 Recommended: Option 1 or 2

**For simplicity**: Use **Option 2** (pre-built vLLM image)  
**For customization**: Use **Option 1** (build on RunPod)

Both work great and avoid the macOS limitation!

---

## Why Not macOS?

vLLM requires:
- ✅ x86_64 architecture (Intel/AMD)
- ✅ Linux OS
- ✅ CUDA-capable NVIDIA GPU
- ❌ Not available for ARM64 (Apple Silicon)
- ❌ Not available for macOS (no CUDA)

Your Mac can still:
- ✅ Develop and test the Flask API locally (without vLLM)
- ✅ Build Docker images remotely
- ✅ Connect to RunPod servers
- ✅ Use the iOS app to test

---

## Quick Copy-Paste Commands for RunPod

```bash
# 1. In RunPod Web Terminal
cd /workspace
git clone https://github.com/your-username/receipt.git
cd receipt

# 2. Build
docker build -f Dockerfile.deepseek -t deepseek-ocr-server:latest .

# 3. Tag
docker tag deepseek-ocr-server:latest YOUR_USERNAME/deepseek-ocr-server:latest

# 4. Push
docker login
docker push YOUR_USERNAME/deepseek-ocr-server:latest

# Done! 🎉
```

Now use `YOUR_USERNAME/deepseek-ocr-server:latest` in your RunPod template!



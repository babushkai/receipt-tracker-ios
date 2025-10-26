# Docker Architecture and Cross-Platform Building

## Understanding the Problem

### Your Setup
- **Development Machine**: macOS (ARM64 if M1/M2/M3, or x86_64 if Intel)
- **Target Server**: RunPod Linux x86_64 with NVIDIA GPU
- **Docker Default**: Builds for host architecture

### The Challenge
By default, when you run `docker build` on macOS:
- **Apple Silicon (M1/M2/M3)**: Builds ARM64 images
- **Intel Mac**: Builds x86_64 images, but without CUDA support
- **RunPod needs**: x86_64 Linux with CUDA

---

## Why vLLM is Special

vLLM requires:
1. ✅ x86_64 architecture (not ARM64)
2. ✅ Linux OS (not macOS)
3. ✅ NVIDIA CUDA GPU (not available on Mac)
4. ✅ CUDA drivers and kernels compiled during installation

**This means**: You cannot build a vLLM Docker image on macOS, even with cross-compilation!

---

## Solutions Ranked by Ease

### 🥇 Solution 1: Build on RunPod (Easiest & Most Reliable)

**Pros**:
- ✅ Native x86_64 Linux build
- ✅ Real GPU/CUDA available
- ✅ Fast build (2-3 minutes with prebuilt base)
- ✅ No cross-compilation issues

**Steps**:
1. Transfer files to RunPod: `./transfer_to_runpod.sh`
2. SSH into RunPod
3. Run build commands (see RUNPOD_BUILD_STEPS.md)

**Cost**: ~$0.27/hour × 0.05 hours = **$0.01 per build**

---

### 🥈 Solution 2: Use Pre-built Base Image (Dockerfile.deepseek.prebuilt)

Instead of building vLLM from scratch, extend the official vLLM image:

```dockerfile
FROM vllm/vllm-openai:latest  # Already built for x86_64 Linux!
RUN pip install flask pillow
COPY deepseek_ocr_server.py /app/
CMD ["python", "deepseek_ocr_server.py"]
```

**Why this works better**:
- vLLM team builds multi-arch images
- You only add Flask (works everywhere)
- Much faster build

**Can you build this on Mac?** 
- Technically yes with `--platform linux/amd64`
- But still not recommended (slow, untested)
- Better to build on RunPod for certainty

---

### 🥉 Solution 3: Docker Buildx with --platform (Not Recommended)

Force x86_64 build on macOS:

```bash
# This will be VERY slow and may fail
docker buildx build \
  --platform linux/amd64 \
  -f Dockerfile.deepseek.prebuilt \
  -t your-username/deepseek-ocr-server:latest \
  --push \
  .
```

**Issues**:
- ⚠️ Extremely slow (emulation overhead)
- ⚠️ May fail due to CUDA requirements
- ⚠️ Can't test GPU functionality locally
- ⚠️ Untested on Apple Silicon

---

### 🏗️ Solution 4: GitHub Actions (Best for CI/CD)

Set up automated builds on GitHub's x86_64 runners:

Create `.github/workflows/build-docker.yml`:

```yaml
name: Build Docker Image

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest  # x86_64 Linux!
    
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
        file: ./Dockerfile.deepseek.prebuilt
        push: true
        tags: ${{ secrets.DOCKER_USERNAME }}/deepseek-ocr-server:latest
```

**Pros**:
- ✅ Automated builds
- ✅ Native x86_64 Linux
- ✅ Free on public repos
- ✅ Builds on every commit

---

## Recommended Workflow

### For Development (Fast Iteration)
1. Develop Python code on your Mac
2. Test locally with mock data (no GPU needed)
3. When ready to deploy: Build on RunPod

### For Production (Reliable)
```bash
# On Mac: Transfer files
./transfer_to_runpod.sh

# On RunPod: Build and push
cd /workspace/deepseek-build
docker build -f Dockerfile.deepseek.prebuilt -t your-username/deepseek-ocr-server:latest .
docker push your-username/deepseek-ocr-server:latest
```

### For Automation (Best Long-term)
- Set up GitHub Actions
- Push to main → Auto build → Auto deploy
- No manual steps needed

---

## Quick Comparison

| Method | Time | Cost | Reliability | Ease |
|--------|------|------|-------------|------|
| Build on RunPod | 3 min | $0.01 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Use prebuilt base | 2 min | $0.01 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Buildx from Mac | 30+ min | Free | ⭐⭐ | ⭐⭐ |
| GitHub Actions | 5 min | Free | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

---

## TL;DR

**Q: Can I build on macOS for RunPod Linux?**  
**A**: Not reliably. vLLM needs GPU/CUDA during build.

**Q: What should I do?**  
**A**: Build on RunPod (costs $0.01, takes 3 minutes) or use GitHub Actions.

**Q: What about `--platform linux/amd64`?**  
**A**: Technically possible but slow, unreliable, and untested for vLLM.

**Q: Best approach?**  
**A**: 
1. Use `transfer_to_runpod.sh` to upload files
2. Build on RunPod with `Dockerfile.deepseek.prebuilt`
3. Push to Docker Hub
4. Deploy anywhere

---

## Files to Help You

- **`transfer_to_runpod.sh`** - Upload files from Mac to RunPod
- **`RUNPOD_BUILD_STEPS.md`** - Step-by-step build guide
- **`Dockerfile.deepseek.prebuilt`** - Fast build using vLLM base
- **`runpod_quickbuild.sh`** - Automated build on RunPod

**Bottom line**: Spend $0.01 and 3 minutes building on RunPod instead of fighting cross-compilation! 🚀



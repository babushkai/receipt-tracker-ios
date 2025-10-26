# GitHub Actions Build Notes

## Disk Space Issues

GitHub Actions free runners have **~14GB** of disk space. Docker image builds (especially with vLLM) can easily exceed this.

### Current Issue
```
System.IO.IOException: No space left on device
```

This happens because:
- Base vLLM image: ~8-10 GB
- Build layers + cache: 3-5 GB
- System files: 2-3 GB
- **Total needed**: 13-18 GB
- **Available**: ~14 GB ❌

## Solutions

### ✅ Option 1: Build on RunPod (Recommended)
**Best for**: Production use, reliable builds, testing with GPU

```bash
# Cost: ~$0.01 per build, 3 minutes
./transfer_to_runpod.sh
# Then build on RunPod
```

**Pros**:
- ✅ Plenty of disk space
- ✅ Real GPU for testing
- ✅ Fast builds (native hardware)
- ✅ Only pay when building

**Cons**:
- ⚠️ Manual process
- ⚠️ Costs $0.01 per build

### ✅ Option 2: Use GitHub's Larger Runners (Paid)
**Best for**: Automated CI/CD with budget

GitHub offers larger runners with more disk space:
- **Standard**: 14GB (free) ❌ Too small
- **Large**: 50GB ($0.008/minute) ✅ Works
- **X-Large**: 100GB ($0.016/minute) ✅ Works great

Update workflow:
```yaml
jobs:
  build:
    runs-on: ubuntu-latest-4-cores  # Larger runner
```

Cost: ~$0.16-0.32 per build (20-minute build)

### ✅ Option 3: Build Locally, Push Tags Only
**Best for**: Free, but less automated

```bash
# Build on your RunPod instance
docker build -f Dockerfile.deepseek.prebuilt -t ghcr.io/babushkai/receipt-tracker-ios/deepseek-ocr:latest .

# Push to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u babushkai --password-stdin
docker push ghcr.io/babushkai/receipt-tracker-ios/deepseek-ocr:latest
```

### ⚠️ Option 4: Optimize Current Workflow (May Still Fail)
The current workflow includes disk cleanup, but may still run out of space.

**Improvements made**:
- Remove unused Android SDK (~8GB)
- Remove .NET SDK (~2GB)
- Remove GHC/Haskell (~1GB)
- Disable SBOM and provenance (saves space)

**May still fail because**:
- vLLM base image is 8-10GB
- Docker needs temp space for layers
- GitHub Actions has limited free space

## Recommended Workflow

### For Development (Free)
1. Develop code locally on Mac
2. Transfer to RunPod: `./transfer_to_runpod.sh`
3. Build on RunPod manually
4. Push to ghcr.io or Docker Hub
5. Deploy

### For Production (Automated)
1. Push code to GitHub
2. Use GitHub's larger runners (paid)
3. Auto-build and push
4. Auto-deploy to RunPod

OR

1. Use RunPod API to trigger remote build
2. Keep builds on RunPod infrastructure
3. GitHub Actions just triggers, doesn't build

## Current Workflow Status

Your current workflow (`build-deepseek-ocr.yml`):
- ✅ Has disk cleanup
- ✅ Uses efficient caching
- ✅ Optimized for space
- ⚠️ **May still fail** on free runners due to vLLM size

## Decision Matrix

| Method | Cost | Reliability | Automation | Speed |
|--------|------|-------------|------------|-------|
| RunPod manual | $0.01/build | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐⭐⭐ |
| GitHub large runners | $0.16-0.32/build | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| GitHub free runners | Free | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Local build + push | Free | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |

## Recommended Setup

**For your use case** (occasional builds, budget-conscious):

1. **Disable automatic GitHub Actions builds**
   - Keep workflow but only trigger manually
   
2. **Build on RunPod when needed**
   ```bash
   ./transfer_to_runpod.sh
   # Build on RunPod
   # Push to ghcr.io
   ```

3. **Cost**: $0.01 per build vs $0.16-0.32 with GitHub Actions

4. **Frequency**: 1-2 builds per month = **$0.01-0.02/month** 🎉

## Alternative: Disable GitHub Actions Build

If you want to only build on RunPod:

```yaml
# Change workflow trigger to manual only
on:
  workflow_dispatch:  # Manual trigger only
  # Remove 'push:' trigger
```

Or delete `.github/workflows/build-deepseek-ocr.yml` entirely.

## Summary

✅ **Best for you**: Build on RunPod manually
- Costs $0.01 per build
- Always works (no disk space issues)
- 3 minutes per build
- Real GPU for testing

❌ **Avoid**: GitHub Actions free runners
- Limited disk space (14GB)
- Will fail for large images like vLLM
- Not worth the debugging time

💰 **If budget allows**: GitHub large runners
- Fully automated
- Costs $0.16-0.32 per build
- Reliable

## Quick Fix Now

Delete or disable the GitHub Actions workflow:

```bash
# Option 1: Disable auto-trigger
git rm .github/workflows/build-deepseek-ocr.yml

# Option 2: Or change to manual only (edit the file)
on:
  workflow_dispatch:  # Manual trigger only
```

Then build on RunPod as planned! 🚀


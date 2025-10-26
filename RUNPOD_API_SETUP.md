# RunPod API Automated Build Setup

## Overview

This setup uses RunPod's API to automatically spin up a GPU pod during GitHub Actions, build your Docker image, push it, and shut down the pod. You only pay for build time (~3-5 minutes = **$0.01 per build**).

## Architecture

```
GitHub Actions Trigger
        ↓
Create RunPod Pod (API)
        ↓
SSH into Pod
        ↓
Build Docker Image
        ↓
Push to ghcr.io
        ↓
Terminate Pod
        ↓
Total Cost: ~$0.01
```

## Setup Steps

### 1. Get RunPod API Key

1. Go to [RunPod Console](https://www.runpod.io/console/user/settings)
2. Navigate to **Settings** → **API Keys**
3. Click **Create API Key**
4. Name it: `github-actions`
5. **Copy the key** (you won't see it again!)

### 2. Add GitHub Secrets

1. Go to your GitHub repo: `https://github.com/babushkai/receipt-tracker-ios/settings/secrets/actions`
2. Click **New repository secret**
3. Add these secrets:

   **Required:**
   - Name: `RUNPOD_API_KEY`
   - Value: `your-runpod-api-key-from-step-1`

   **Optional** (already auto-configured):
   - `GITHUB_TOKEN` - Auto-provided by GitHub Actions
   - `DOCKER_USERNAME` - Only if pushing to Docker Hub
   - `DOCKER_PASSWORD` - Only if pushing to Docker Hub

### 3. Enable GitHub Actions Workflow

The workflow is already created at `.github/workflows/build-on-runpod-automated.yml`.

It will automatically trigger when you push changes to:
- `deepseek_ocr_server.py`
- `Dockerfile.deepseek*`
- The workflow file itself

Or manually trigger it:
1. Go to **Actions** tab
2. Select **Build on RunPod (Automated)**
3. Click **Run workflow**

## How It Works

### Workflow Steps

1. **GitHub Actions starts** on your commit
2. **Python script runs** (`scripts/runpod_build_automation.py`)
3. **RunPod API creates pod**:
   - GPU: RTX 4000 Ada (spot instance)
   - Disk: 30GB
   - Template: PyTorch with Docker
4. **Waits for pod** to be running (~1-2 minutes)
5. **SSHs into pod** automatically
6. **Executes build**:
   ```bash
   git clone your-repo
   docker build -f Dockerfile.deepseek.prebuilt -t image:latest .
   docker push ghcr.io/babushkai/receipt-tracker-ios/deepseek-ocr:latest
   ```
7. **Terminates pod** automatically
8. **Total time**: 3-5 minutes
9. **Total cost**: ~$0.01

### Script Features

The automation script (`scripts/runpod_build_automation.py`):
- ✅ Creates pod with RunPod API
- ✅ Waits for pod to be ready
- ✅ SSHs in automatically
- ✅ Streams build logs in real-time
- ✅ Pushes to GitHub Container Registry
- ✅ Cleans up pod automatically
- ✅ Handles errors gracefully
- ✅ Shows cost estimate

## Manual Testing

Test the automation locally before using in GitHub Actions:

```bash
# Install dependencies
cd scripts
pip install -r requirements.txt

# Set environment variables
export RUNPOD_API_KEY="your-api-key"
export GITHUB_REPOSITORY="babushkai/receipt-tracker-ios"
export GITHUB_SHA="main"
export GITHUB_TOKEN="your-github-token"  # For pushing images

# Run the script
python3 runpod_build_automation.py
```

## Cost Breakdown

**Per Build**:
- Pod creation: Free
- Build time: 3-5 minutes
- RTX 4000 Ada Spot: $0.26/hour
- **Cost**: 4 minutes × $0.26/60 = **$0.017** (~$0.02)

**Monthly** (assuming 5 builds):
- 5 builds × $0.02 = **$0.10/month** 🎉

Compare to:
- GitHub large runners: $0.16-0.32 per build = **$0.80-1.60/month**
- Manual builds on RunPod: Same cost, but manual

## Advantages

✅ **Automated**: Push code → builds automatically  
✅ **Cheap**: Only pay for build time (~$0.01)  
✅ **No disk issues**: RunPod has plenty of space  
✅ **Real GPU**: Can test on actual hardware  
✅ **Spot pricing**: 40-50% cheaper  
✅ **Auto cleanup**: Pods terminate automatically  

## Troubleshooting

### "Pod failed to start"
- **Cause**: No spot instances available
- **Fix**: Script will retry or use on-demand (more expensive)

### "SSH connection failed"
- **Cause**: Pod not fully initialized
- **Fix**: Script waits up to 5 minutes; increase timeout if needed

### "Build failed"
- **Cause**: Various (check logs)
- **Fix**: Debug by running script locally with same environment variables

### "No RUNPOD_API_KEY"
- **Cause**: Secret not set in GitHub
- **Fix**: Add `RUNPOD_API_KEY` to repository secrets

### Pod not terminating
- **Cause**: Script error before cleanup
- **Fix**: Manually stop at [RunPod Console](https://www.runpod.io/console/pods)

## Monitoring

### View Build Progress

1. Go to GitHub Actions: `https://github.com/babushkai/receipt-tracker-ios/actions`
2. Click on running workflow
3. Watch real-time logs

### Monitor RunPod Costs

1. Go to [RunPod Billing](https://www.runpod.io/console/user/billing)
2. View usage and costs
3. Set spending limits if desired

## Alternative: Manual Control

If you prefer manual control, use the simpler workflow:

`.github/workflows/build-on-runpod.yml` - Creates pod but requires manual SSH build

## Comparison

| Method | Automation | Cost/Build | Disk Space | Setup |
|--------|-----------|------------|------------|-------|
| **RunPod API (This)** | ⭐⭐⭐⭐⭐ | $0.01 | ✅ 30GB | ⭐⭐⭐ |
| Manual RunPod | ⭐ | $0.01 | ✅ 30GB | ⭐⭐⭐⭐⭐ |
| GitHub Large | ⭐⭐⭐⭐⭐ | $0.16-0.32 | ✅ 50GB | ⭐⭐⭐⭐ |
| GitHub Free | ⭐⭐⭐⭐⭐ | Free | ❌ 14GB | ⭐⭐⭐⭐⭐ |

## Security

✅ **API Key**: Stored as GitHub secret (encrypted)  
✅ **SSH**: Automatic, no keys stored  
✅ **Cleanup**: Pods auto-terminate (no lingering costs)  
✅ **Logs**: Sensitive data filtered  

## Next Steps

1. ✅ Get RunPod API key
2. ✅ Add to GitHub secrets
3. ✅ Push code to trigger build
4. ✅ Watch it build automatically!

🎉 **Result**: Fully automated Docker builds for ~$0.01 each!


# Troubleshooting Guide

## RunPod API Issues

### Error: "Unauthorized request, please check your API key"

**Cause**: RunPod API key is missing, invalid, or incorrect.

**Solutions**:

#### 1. Check if Secret is Set

Go to: `https://github.com/babushkai/receipt-tracker-ios/settings/secrets/actions`

Look for: `RUNPOD_API_KEY`

If missing:
1. Click **New repository secret**
2. Name: `RUNPOD_API_KEY`
3. Value: Your RunPod API key
4. Click **Add secret**

#### 2. Get a Valid API Key

1. Go to [RunPod API Settings](https://www.runpod.io/console/user/settings)
2. Navigate to **API Keys** section
3. Click **+ Create API Key**
4. Name it: `github-actions`
5. **Copy the key immediately** (you won't see it again!)
6. Format should look like: `XXXXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`

#### 3. Update GitHub Secret

If you already have the secret but it's not working:

1. Go to: `https://github.com/babushkai/receipt-tracker-ios/settings/secrets/actions`
2. Click on `RUNPOD_API_KEY`
3. Click **Update secret**
4. Paste your **new** API key from RunPod
5. Click **Update secret**

#### 4. Verify API Key Works

Test locally before GitHub Actions:

```bash
# Install dependencies
pip install runpod

# Test API key
python3 << 'EOF'
import runpod
import os

api_key = input("Paste your RunPod API key: ")
runpod.api_key = api_key

try:
    # Try to list GPUs (simple API call)
    gpus = runpod.get_gpus()
    print("✅ API key is valid!")
    print(f"📊 Available GPU types: {len(gpus)}")
except Exception as e:
    print(f"❌ API key is invalid: {e}")
EOF
```

#### 5. Common Mistakes

❌ **Wrong**: Copying API key with extra spaces or newlines  
✅ **Right**: Copy entire key, trim whitespace

❌ **Wrong**: Using expired or deleted API key  
✅ **Right**: Create a fresh API key

❌ **Wrong**: Setting secret name as `RUNPOD_API` or `RUNPOD_KEY`  
✅ **Right**: Must be exactly `RUNPOD_API_KEY`

❌ **Wrong**: Key format like `runpod_xxxxx`  
✅ **Right**: RunPod keys look like `XXXXXX-XXXXXXXXXXXXXXXX`

---

## GitHub Actions Issues

### Workflow Not Triggering

**Check**:
1. Go to **Actions** tab in GitHub
2. Look for disabled workflows
3. Enable if needed

### Workflow Fails Immediately

**Check logs**:
1. Go to **Actions** tab
2. Click failed run
3. Expand each step to see errors

---

## Building Issues

### "No space left on device" on GitHub Actions

**Solution**: Use RunPod API method (this repo's setup) instead of building directly on GitHub runners.

### Build succeeds but image not pushed

**Check**:
1. Verify `GITHUB_TOKEN` has write permissions
2. Enable GitHub Container Registry:
   - Go to repo **Settings** → **Actions** → **General**
   - Under **Workflow permissions**: Select **Read and write permissions**

---

## SSH Connection Issues

### "SSH connection failed" in automation script

**Causes**:
- Pod not fully initialized yet
- Network issues
- SSH port not exposed

**Solutions**:
1. Script already waits 5 minutes - usually enough
2. Check RunPod console for pod status
3. Verify pod has SSH port (22/tcp) exposed

### Manual SSH timeout

**Check**:
```bash
# Test SSH connectivity
ssh -v -p <port> root@<host>
```

---

## Cost Issues

### Unexpected charges

**Check**:
1. Go to [RunPod Billing](https://www.runpod.io/console/user/billing)
2. Look for pods that didn't terminate
3. Manually stop any running pods

**Prevention**:
- Automation script terminates pods automatically
- Set RunPod spending limits
- Use SPOT instances (cheaper)

---

## Image Push Issues

### "authentication required" when pushing to ghcr.io

**Solution**:
1. Go to repo **Settings** → **Actions** → **General**
2. Under **Workflow permissions**:
   - Select **Read and write permissions**
3. Save changes

### Image pushed but can't pull

**Check package permissions**:
1. Go to your GitHub profile
2. Click **Packages**
3. Find `deepseek-ocr` package
4. Click **Package settings**
5. Make sure visibility is set correctly

---

## Local Testing Issues

### "runpod module not found"

```bash
pip install runpod paramiko
```

### "paramiko module not found"

```bash
pip install paramiko
```

---

## Quick Diagnostic Commands

### Test RunPod API Key
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://api.runpod.io/graphql \
  -d '{"query": "{ myself { id } }"}'
```

### Test GitHub Token
```bash
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/user
```

### List GitHub Secrets (names only)
```bash
gh secret list
```

### Check Docker Login
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

---

## Getting Help

### RunPod Issues
- [RunPod Discord](https://discord.gg/runpod)
- [RunPod Docs](https://docs.runpod.io/)
- [RunPod Support](https://www.runpod.io/support)

### GitHub Actions Issues
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- Check this repo's Issues tab

### Docker Issues
- [Docker Docs](https://docs.docker.com/)
- [vLLM Docs](https://docs.vllm.ai/)

---

## Common Questions

**Q: How much will this cost?**  
A: ~$0.01 per build (3-5 minutes on RTX 4000 Ada spot)

**Q: Can I use a different GPU?**  
A: Yes, edit `GPU_TYPE` in `scripts/runpod_build_automation.py`

**Q: Why not build on GitHub Actions directly?**  
A: vLLM Docker images are ~10GB, GitHub free runners have only 14GB disk space

**Q: Can I use Docker Hub instead of ghcr.io?**  
A: Yes, add `DOCKER_USERNAME` and `DOCKER_PASSWORD` secrets, update script

**Q: How do I disable automated builds?**  
A: Delete or rename `.github/workflows/build-on-runpod-automated.yml`

**Q: Can I build manually?**  
A: Yes! Use `./transfer_to_runpod.sh` and build directly on RunPod

---

## Still Having Issues?

1. Check GitHub Actions logs for detailed errors
2. Test RunPod API key locally with test script above
3. Verify all secrets are set correctly
4. Try manual build on RunPod first to isolate issue
5. Open an issue in this repo with error logs

---

## Checklist Before Opening Issue

- [ ] RunPod API key is valid and set in GitHub secrets
- [ ] GitHub token has write permissions
- [ ] Workflow file is in correct location
- [ ] All required files are committed (scripts/, Dockerfile, etc.)
- [ ] Tested locally with same environment variables
- [ ] Checked GitHub Actions logs for specific error
- [ ] Verified no typos in secret names


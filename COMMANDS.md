# 🚀 Quick Command Reference

## 📤 Push to GitHub (2 Commands)

```bash
# 1. Add and commit everything
git add .
git commit -m "feat: Add Docker support for OCR backend"

# 2. Push (triggers automatic build!)
git push origin main

# ✅ Done! GitHub Actions will build and push automatically
# View progress: https://github.com/babushkai/receipt-tracker-ios/actions
```

## 🐳 Use Pre-built Image (1 Command)

```bash
# Pull and run (after GitHub Actions finishes)
docker run -d --name receipt-ocr --gpus all \
  -p 8000:8000 \
  -e API_KEY_IOS="$(openssl rand -hex 16)" \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest
```

## 🔨 Manual Build (Local Testing)

```bash
# Build locally
docker build -t receipt-ocr:local -f Dockerfile .

# Run locally
docker run -d --name receipt-ocr --gpus all \
  -p 8000:8000 \
  -e API_KEY_IOS="test_key_123" \
  receipt-ocr:local

# Test
curl http://localhost:8000/health
```

## 📦 Manual Push to GHCR

```bash
# 1. Login (one-time)
echo "YOUR_GITHUB_TOKEN" | docker login ghcr.io -u babushkai --password-stdin

# 2. Tag
docker tag receipt-ocr:local \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest

# 3. Push
docker push ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest
```

## 🧪 Test the API

```bash
# Health check
curl http://localhost:8000/health

# OCR test (Swiss receipt)
curl -X POST http://localhost:8000/api/v1/ocr \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://upload.wikimedia.org/wikipedia/commons/0/0b/ReceiptSwiss.jpg",
    "prompt": "Extract all text."
  }'

# Check usage
curl http://localhost:8000/api/v1/usage \
  -H "X-API-Key: your-api-key"
```

## 🔍 Debugging

```bash
# View logs
docker logs -f receipt-ocr

# Enter container
docker exec -it receipt-ocr bash

# Check GPU
nvidia-smi

# Restart container
docker restart receipt-ocr

# Stop and remove
docker stop receipt-ocr && docker rm receipt-ocr
```

## 🏷️ Version Release

```bash
# Create tagged release
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Image will be at:
# ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:v1.0.0
```

## 🌐 Production Deploy

```bash
# SSH to server
ssh user@your-server.com

# Run in production
docker run -d \
  --name receipt-ocr \
  --gpus all \
  --restart unless-stopped \
  -p 8000:8000 \
  -e API_KEY_IOS="production-key-here" \
  -v /data/model_cache:/app/model_cache \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest
```

## 📊 Monitoring

```bash
# Container stats
docker stats receipt-ocr

# GPU usage
watch -n 1 nvidia-smi

# Disk usage
docker system df

# View all images
docker images | grep ocr-backend
```

## 🔄 Update to Latest

```bash
# Pull latest
docker pull ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest

# Restart with new image
docker stop receipt-ocr && docker rm receipt-ocr
docker run -d ... (same command as before)
```

## 🐙 GitHub Actions

```bash
# View builds
open https://github.com/babushkai/receipt-tracker-ios/actions

# View packages
open https://github.com/babushkai/receipt-tracker-ios/packages
```

## 🔐 Generate API Keys

```bash
# iOS app key
openssl rand -hex 16

# Or UUID-based
uuidgen | tr '[:upper:]' '[:lower:]'

# Secure random
python3 -c "import secrets; print(f'ios_app_{secrets.token_urlsafe(32)}')"
```

---

**📚 Full Documentation**: See [README_DOCKER.md](README_DOCKER.md) and [DOCKER_GUIDE.md](DOCKER_GUIDE.md)


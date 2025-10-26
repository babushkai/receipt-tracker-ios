# 🐳 Docker Guide - Receipt Tracker OCR Backend

Complete guide to building, pushing, and deploying the OCR backend as a Docker container.

## 📦 What's Included

The Docker image includes:
- **DeepSeek OCR Server** (port 5003) - GPU-accelerated OCR using vLLM
- **Secure Gateway API** (port 8000) - Authentication & rate limiting
- **Health checks** and automatic restarts
- **Model caching** for faster startups

## 🚀 Quick Start

### Option 1: Use Pre-built Image from GitHub Container Registry

```bash
# Pull the latest image
docker pull ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest

# Run with GPU support
docker run -d \
  --name receipt-ocr \
  --gpus all \
  -p 8000:8000 \
  -p 5003:5003 \
  -e API_KEY_IOS="your-secure-api-key-here" \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest

# Check logs
docker logs -f receipt-ocr
```

### Option 2: Use Docker Compose (Recommended)

```bash
# Clone the repo
git clone https://github.com/babushkai/receipt-tracker-ios.git
cd receipt-tracker-ios/deepseek-build

# Create .env file with your API keys
cat > .env << EOF
API_KEY_IOS=ios_app_$(openssl rand -hex 16)
API_KEY_WEB=web_app_$(openssl rand -hex 16)
EOF

# Start services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

## 🛠️ Building the Image

### Prerequisites

- Docker 20.10+ with BuildKit
- NVIDIA Docker (nvidia-docker2) for GPU support
- GPU with CUDA 12.1+ support
- ~10GB disk space for build
- GitHub account with access to your repository

### Manual Build

```bash
# Navigate to the build directory
cd /workspace/deepseek-build

# Build the image
docker build -t receipt-ocr-backend:local -f Dockerfile .

# Or with cache and buildx
docker buildx build \
  --platform linux/amd64 \
  --cache-from type=local,src=/tmp/docker-cache \
  --cache-to type=local,dest=/tmp/docker-cache \
  -t receipt-ocr-backend:local \
  -f Dockerfile \
  .

# Test locally
docker run --rm --gpus all -p 8000:8000 receipt-ocr-backend:local
```

## 📤 Pushing to GitHub Container Registry

### Setup

1. **Create Personal Access Token (PAT)**:
   - Go to: https://github.com/settings/tokens
   - Click "Generate new token" → "Generate new token (classic)"
   - Select scopes:
     - ✅ `write:packages`
     - ✅ `read:packages`
     - ✅ `delete:packages`
   - Generate and save the token

2. **Login to GHCR**:
```bash
# Save token to file (temporary)
echo "YOUR_GITHUB_TOKEN" > token.txt

# Login
cat token.txt | docker login ghcr.io -u babushkai --password-stdin

# Remove token file
rm token.txt
```

### Manual Push

```bash
# Tag the image
docker tag receipt-ocr-backend:local \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest

# Push to GitHub Container Registry
docker push ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest

# Push with version tag
docker tag receipt-ocr-backend:local \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:v1.0.0
docker push ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:v1.0.0
```

## 🤖 Automatic Builds with GitHub Actions

The repository includes a GitHub Actions workflow that automatically builds and pushes images.

### How It Works

1. **Triggers**:
   - Push to `main` branch → builds `latest` tag
   - Create tag `v*.*.*` → builds versioned release
   - Pull requests → builds (but doesn't push)
   - Manual trigger → builds on demand

2. **Setup** (one-time):
   ```bash
   # The workflow uses GITHUB_TOKEN automatically
   # No additional setup needed!
   ```

3. **Create a release**:
   ```bash
   # Commit your changes
   git add .
   git commit -m "feat: updated OCR backend"
   
   # Create and push tag for versioned release
   git tag v1.0.0
   git push origin v1.0.0
   
   # Or just push to main for latest
   git push origin main
   ```

4. **Monitor build**:
   - Go to: https://github.com/babushkai/receipt-tracker-ios/actions
   - Watch the build progress
   - Once complete, image available at:
     ```
     ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest
     ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:v1.0.0
     ```

### GitHub Actions Workflow

The workflow (`.github/workflows/docker-publish.yml`) includes:
- ✅ Multi-platform support (linux/amd64)
- ✅ Layer caching for faster builds
- ✅ Automatic tagging (latest, version, sha)
- ✅ Build provenance attestation
- ✅ Metadata generation

## 🔧 Configuration

### Environment Variables

```bash
# Gateway Configuration
API_KEY_IOS=your-ios-api-key          # iOS app API key
API_KEY_WEB=your-web-api-key          # Web app API key (optional)
OCR_SERVER_URL=http://localhost:5003  # Internal OCR server URL

# Optional: Resource limits
CUDA_VISIBLE_DEVICES=0                # GPU to use (0 for first GPU)
HF_HOME=/app/model_cache              # Model cache directory
```

### Running Modes

```bash
# Mode 1: Both services (default)
docker run --gpus all -p 8000:8000 -p 5003:5003 \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest both

# Mode 2: OCR Server only
docker run --gpus all -p 5003:5003 \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest ocr-only

# Mode 3: Gateway only (requires external OCR server)
docker run -p 8000:8000 \
  -e OCR_SERVER_URL=http://external-ocr:5003 \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest gateway-only
```

## 📊 Resource Requirements

| Component | CPU | RAM | GPU VRAM | Storage |
|-----------|-----|-----|----------|---------|
| Minimum   | 4   | 8GB | 8GB      | 20GB    |
| Recommended | 8 | 16GB | 16GB   | 50GB    |
| Optimal   | 16  | 32GB | 24GB+    | 100GB   |

## 🔍 Health Checks & Monitoring

### Health Endpoints

```bash
# Gateway health
curl http://localhost:8000/health

# OCR server health
curl http://localhost:5003/health

# Docker health status
docker ps --filter name=receipt-ocr
```

### View Logs

```bash
# Follow logs
docker logs -f receipt-ocr

# Last 100 lines
docker logs --tail 100 receipt-ocr

# With docker-compose
docker-compose logs -f ocr-backend
```

### Monitoring

```bash
# Container stats
docker stats receipt-ocr

# GPU usage
nvidia-smi

# Inside container
docker exec -it receipt-ocr bash
ps aux
nvidia-smi
```

## 🌐 Production Deployment

### 1. With NGINX Reverse Proxy

```nginx
# /etc/nginx/sites-available/receipt-ocr
server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts for OCR processing
        proxy_connect_timeout 120s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }
}
```

### 2. With Docker Compose + NGINX

```bash
# Start with NGINX profile
docker-compose --profile production up -d
```

### 3. On Cloud Platforms

**AWS**:
```bash
# Using ECS with GPU instances
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com

docker pull ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest
docker tag ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest \
  <account>.dkr.ecr.us-east-1.amazonaws.com/receipt-ocr:latest
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/receipt-ocr:latest
```

**GCP**:
```bash
gcloud auth configure-docker
docker pull ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest
docker tag ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest \
  gcr.io/<project-id>/receipt-ocr:latest
docker push gcr.io/<project-id>/receipt-ocr:latest
```

**RunPod**:
```bash
# Use the GHCR image directly in RunPod template
# Image: ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest
# Expose ports: 8000, 5003
```

## 🧪 Testing the Deployment

```bash
# Test health
curl https://api.yourdomain.com/health

# Test OCR with authentication
curl -X POST https://api.yourdomain.com/api/v1/ocr \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://upload.wikimedia.org/wikipedia/commons/0/0b/ReceiptSwiss.jpg",
    "prompt": "Extract all text."
  }'

# Check usage
curl https://api.yourdomain.com/api/v1/usage \
  -H "X-API-Key: your-api-key"
```

## 🐛 Troubleshooting

### Container won't start

```bash
# Check logs
docker logs receipt-ocr

# Common issues:
# 1. GPU not available
nvidia-smi  # Check if GPU is visible

# 2. Port already in use
lsof -i :8000  # Check what's using port 8000

# 3. Insufficient memory
free -h  # Check available RAM
```

### GPU not detected

```bash
# Verify NVIDIA Docker runtime
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# Check Docker daemon config
cat /etc/docker/daemon.json
# Should include: "default-runtime": "nvidia"

# Restart Docker
sudo systemctl restart docker
```

### Model download fails

```bash
# Use model cache volume
docker run -v ./model_cache:/app/model_cache ...

# Pre-download models
docker exec -it receipt-ocr bash
python3 -c "from transformers import AutoModel; AutoModel.from_pretrained('deepseek-ai/DeepSeek-OCR')"
```

## 🔐 Security Best Practices

1. **Change default API keys** immediately
2. **Use environment variables** for secrets
3. **Don't expose port 5003** publicly (OCR server should be internal)
4. **Use HTTPS** with valid SSL certificates
5. **Enable firewall** rules
6. **Regular updates**: `docker pull ghcr.io/.../ocr-backend:latest`
7. **Monitor logs** for suspicious activity
8. **Set resource limits** in docker-compose.yml

## 📝 Updating the Image

```bash
# Pull latest image
docker-compose pull

# Restart with new image
docker-compose up -d

# Or with plain Docker
docker pull ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest
docker stop receipt-ocr
docker rm receipt-ocr
docker run -d ... (same command as before)
```

## 📞 Support

- **GitHub Issues**: https://github.com/babushkai/receipt-tracker-ios/issues
- **Package Registry**: https://github.com/babushkai/receipt-tracker-ios/pkgs/container/receipt-tracker-ios%2Focr-backend
- **Actions**: https://github.com/babushkai/receipt-tracker-ios/actions

---

**Built with ❤️ for Receipt Tracker iOS**


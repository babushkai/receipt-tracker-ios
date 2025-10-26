# 🐳 Receipt Tracker OCR - Docker Deployment

Production-ready Docker image for the OCR backend powering the [Receipt Tracker iOS app](https://github.com/babushkai/receipt-tracker-ios).

## 🎯 Quick Start (3 Commands!)

```bash
# 1. Pull the image
docker pull ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest

# 2. Run with your API key
docker run -d --name receipt-ocr --gpus all \
  -p 8000:8000 \
  -e API_KEY_IOS="$(openssl rand -hex 16)" \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest

# 3. Test it
curl http://localhost:8000/health
```

## 📦 What You Get

This Docker image includes everything needed for production OCR:

| Component | Description | Port |
|-----------|-------------|------|
| **DeepSeek OCR Server** | GPU-accelerated OCR using vLLM | 5003 |
| **Secure Gateway API** | Authentication, rate limiting, validation | 8000 |
| **Health Checks** | Automatic monitoring and restarts | - |
| **Model Caching** | Faster startups with persistent cache | - |

## 🚀 Deployment Options

### Option 1: Docker Run (Simple)

```bash
docker run -d \
  --name receipt-ocr \
  --gpus all \
  --restart unless-stopped \
  -p 8000:8000 \
  -e API_KEY_IOS="your-secure-key-here" \
  -v $(pwd)/model_cache:/app/model_cache \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest
```

### Option 2: Docker Compose (Recommended)

```bash
# Create docker-compose.yml (see DOCKER_GUIDE.md)
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Option 3: Production with NGINX

```bash
# Use production profile
docker-compose --profile production up -d
```

## 🔧 Configuration

### Environment Variables

```bash
# Required
API_KEY_IOS=your-ios-app-key          # iOS app authentication

# Optional
API_KEY_WEB=your-web-app-key          # Web app authentication
OCR_SERVER_URL=http://localhost:5003  # Internal OCR endpoint
CUDA_VISIBLE_DEVICES=0                # GPU selection
```

### Running Modes

```bash
# Both services (default)
docker run ... ocr-backend:latest both

# OCR server only (internal use)
docker run -p 5003:5003 ... ocr-backend:latest ocr-only

# Gateway only (requires external OCR)
docker run -p 8000:8000 -e OCR_SERVER_URL=http://ocr:5003 ... gateway-only
```

## 📱 iOS App Integration

Update your iOS app to point to your Docker deployment:

```swift
// In OCRClient.swift
class OCRClient {
    // Change this to your server URL
    private let baseURL = "https://api.yourdomain.com"  // With NGINX + SSL
    // or
    private let baseURL = "http://your-server-ip:8000"  // Direct access
    
    // Your API key (store in Keychain!)
    private let apiKey = "your-api-key-here"
}
```

## 🏗️ Building from Source

### Manual Build

```bash
cd /workspace/deepseek-build

# Build the image
docker build -t receipt-ocr-backend:local -f Dockerfile .

# Test locally
docker run --rm --gpus all -p 8000:8000 receipt-ocr-backend:local
```

### Automated Build & Push

```bash
# Use the helper script
./BUILD_AND_PUSH.sh v1.0.0

# Or push to GitHub manually
docker tag receipt-ocr-backend:local \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:v1.0.0
  
docker push ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:v1.0.0
```

## 🤖 GitHub Actions (Automatic)

The repository includes a workflow that automatically:
- ✅ Builds on every push to `main`
- ✅ Creates versioned releases on tags (`v*.*.*`)
- ✅ Caches layers for faster builds
- ✅ Publishes to GitHub Container Registry

### Create a Release

```bash
# Commit your changes
git add .
git commit -m "feat: improved OCR accuracy"

# Tag and push
git tag v1.0.0
git push origin v1.0.0

# Check build status
# https://github.com/babushkai/receipt-tracker-ios/actions
```

## 🔐 Security Setup

### 1. Generate Secure API Keys

```bash
# For iOS app
export API_KEY_IOS="ios_app_$(openssl rand -hex 16)"

# For web app (optional)
export API_KEY_WEB="web_app_$(openssl rand -hex 16)"

# Save these securely!
echo "iOS API Key: $API_KEY_IOS"
echo "Web API Key: $API_KEY_WEB"
```

### 2. Use Environment Files

```bash
# Create .env file
cat > .env << EOF
API_KEY_IOS=${API_KEY_IOS}
API_KEY_WEB=${API_KEY_WEB}
EOF

# Use with Docker
docker run --env-file .env ... ocr-backend:latest

# Or with docker-compose
docker-compose --env-file .env up -d
```

### 3. SSL with Let's Encrypt

```bash
# Install certbot
sudo apt install certbot

# Get certificate
sudo certbot certonly --standalone -d api.yourdomain.com

# Update nginx.conf to use certificates
# See DOCKER_GUIDE.md for complete NGINX configuration
```

## 📊 Monitoring

### Check Health

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

# Search logs
docker logs receipt-ocr 2>&1 | grep ERROR
```

### Resource Usage

```bash
# Container stats
docker stats receipt-ocr

# GPU usage
nvidia-smi

# Disk usage
docker system df
```

## 🧪 Testing

### Test OCR Endpoint

```bash
# Health check
curl http://localhost:8000/health

# OCR with authentication
curl -X POST http://localhost:8000/api/v1/ocr \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://upload.wikimedia.org/wikipedia/commons/0/0b/ReceiptSwiss.jpg",
    "prompt": "Extract all text from this receipt."
  }'

# Check usage stats
curl http://localhost:8000/api/v1/usage \
  -H "X-API-Key: your-api-key"
```

### Performance Test

```bash
# Run multiple requests
for i in {1..10}; do
  curl -X POST http://localhost:8000/api/v1/ocr \
    -H "X-API-Key: your-api-key" \
    -H "Content-Type: application/json" \
    -d '{"image": "https://example.com/receipt.jpg"}' &
done
wait
```

## 🔧 Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs receipt-ocr

# Verify GPU
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# Check port conflicts
lsof -i :8000
lsof -i :5003
```

### GPU Not Detected

```bash
# Install nvidia-docker2
sudo apt install nvidia-docker2
sudo systemctl restart docker

# Verify installation
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

### Out of Memory

```bash
# Check GPU memory
nvidia-smi

# Reduce batch size or model settings
# Edit deepseek_ocr_server.py: gpu_memory_utilization=0.6

# Add swap space (if needed)
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## 🌐 Cloud Deployment

### AWS EC2 with GPU

```bash
# Launch g4dn.xlarge or similar
# Install Docker + NVIDIA drivers
curl -fsSL https://get.docker.com | sh
sudo apt install nvidia-docker2

# Run the container
docker run -d --gpus all -p 8000:8000 \
  -e API_KEY_IOS="your-key" \
  ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest
```

### Google Cloud Platform

```bash
# Create VM with GPU
gcloud compute instances create receipt-ocr \
  --machine-type=n1-standard-4 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud

# SSH and install Docker + NVIDIA runtime
# Run container as above
```

### RunPod.io

```bash
# Use GPU pod with Docker template
# Image: ghcr.io/babushkai/receipt-tracker-ios/ocr-backend:latest
# Exposed ports: 8000
# Environment variables: Add your API keys
```

## 💰 Cost Optimization

1. **Use smaller GPU instances** for light workloads
2. **Enable auto-scaling** based on load
3. **Use spot instances** for development
4. **Cache models** in persistent volumes
5. **Batch requests** when possible

## 📚 Documentation

- **[DOCKER_GUIDE.md](DOCKER_GUIDE.md)** - Complete Docker documentation
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Production deployment guide
- **[ios_example.swift](ios_example.swift)** - iOS integration code
- **[deepseek_ocr_server.py](deepseek_ocr_server.py)** - OCR server code
- **[secure_ocr_gateway.py](secure_ocr_gateway.py)** - Gateway API code

## 📦 Package Registry

View published images:
- **Latest**: https://github.com/babushkai/receipt-tracker-ios/pkgs/container/receipt-tracker-ios%2Focr-backend
- **Versions**: All tagged versions available

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `docker build`
5. Submit a pull request

## 📄 License

This project is part of the Receipt Tracker iOS app.

## 📞 Support

- **Issues**: https://github.com/babushkai/receipt-tracker-ios/issues
- **Actions**: https://github.com/babushkai/receipt-tracker-ios/actions
- **Packages**: https://github.com/babushkai/receipt-tracker-ios/packages

---

**🎉 You now have a production-ready OCR backend for your Receipt Tracker iOS app!**

Quick links:
- 📱 [iOS App Repo](https://github.com/babushkai/receipt-tracker-ios)
- 🐳 [Docker Hub](https://github.com/babushkai/receipt-tracker-ios/pkgs/container/receipt-tracker-ios%2Focr-backend)
- 📖 [Full Documentation](DOCKER_GUIDE.md)


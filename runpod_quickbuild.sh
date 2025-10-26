#!/bin/bash
# Quick build script for RunPod - copy/paste this into your RunPod terminal
# This will build using the pre-built vLLM image (fastest method)

set -e

echo "🚀 DeepSeek-OCR Quick Build for RunPod"
echo "======================================"
echo ""

# Check if running on RunPod/Linux
if [[ ! -f /etc/os-release ]]; then
    echo "❌ This must run on Linux (RunPod)"
    exit 1
fi

echo "📍 Current directory: $(pwd)"
echo ""

# Get Docker Hub username
read -p "Enter your Docker Hub username: " DOCKER_USERNAME
if [ -z "$DOCKER_USERNAME" ]; then
    echo "❌ Docker Hub username required"
    exit 1
fi

IMAGE_NAME="${DOCKER_USERNAME}/deepseek-ocr-server:latest"
echo "Will build: ${IMAGE_NAME}"
echo ""

# Check if files exist
if [ ! -f "deepseek_ocr_server.py" ]; then
    echo "❌ deepseek_ocr_server.py not found!"
    echo "💡 Make sure you're in the correct directory"
    echo "   Current dir: $(pwd)"
    exit 1
fi

if [ ! -f "Dockerfile.deepseek.prebuilt" ] && [ ! -f "Dockerfile.deepseek" ]; then
    echo "❌ No Dockerfile found!"
    echo "💡 Upload Dockerfile.deepseek.prebuilt or Dockerfile.deepseek"
    exit 1
fi

# Choose Dockerfile
if [ -f "Dockerfile.deepseek.prebuilt" ]; then
    DOCKERFILE="Dockerfile.deepseek.prebuilt"
    echo "✅ Using Dockerfile.deepseek.prebuilt (fastest!)"
else
    DOCKERFILE="Dockerfile.deepseek"
    echo "✅ Using Dockerfile.deepseek"
fi

# Build
echo ""
echo "🔨 Building Docker image..."
echo "⏱️  This will take 2-15 minutes depending on Dockerfile..."
echo ""

docker build -f ${DOCKERFILE} -t ${IMAGE_NAME} .

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "✅ Build successful!"
echo ""

# Show image info
echo "📊 Image info:"
docker images ${IMAGE_NAME} --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
echo ""

# Test locally (optional)
read -p "🧪 Test locally before pushing? (y/n) [n]: " test_choice
test_choice=${test_choice:-n}

if [[ $test_choice =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Starting container for testing..."
    docker run -d --gpus all -p 5003:5003 --name deepseek-test ${IMAGE_NAME}
    
    echo "⏳ Waiting 30 seconds for model to load..."
    sleep 30
    
    echo "🔍 Testing health endpoint..."
    if curl -s http://localhost:5003/health | grep -q "ok"; then
        echo "✅ Server is healthy!"
    else
        echo "⚠️  Server may not be ready yet, check logs:"
        docker logs deepseek-test
    fi
    
    echo ""
    read -p "Press Enter to stop test container and continue..."
    docker stop deepseek-test
    docker rm deepseek-test
fi

# Push to Docker Hub
echo ""
read -p "📤 Push to Docker Hub? (y/n) [y]: " push_choice
push_choice=${push_choice:-y}

if [[ $push_choice =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔐 Logging in to Docker Hub..."
    docker login
    
    if [ $? -ne 0 ]; then
        echo "❌ Login failed"
        exit 1
    fi
    
    echo ""
    echo "📤 Pushing ${IMAGE_NAME}..."
    docker push ${IMAGE_NAME}
    
    echo ""
    echo "🎉 SUCCESS! Image pushed to Docker Hub!"
    echo ""
    echo "════════════════════════════════════════"
    echo "🎯 NEXT STEPS:"
    echo "════════════════════════════════════════"
    echo ""
    echo "1️⃣  Stop this build pod (save money!)"
    echo "    RunPod Dashboard → Your Pod → Stop/Terminate"
    echo ""
    echo "2️⃣  Create RunPod Template:"
    echo "    - Go to: Templates → New Template"
    echo "    - Docker Image: ${IMAGE_NAME}"
    echo "    - Container Disk: 20 GB"
    echo "    - Expose HTTP Port: 5003"
    echo ""
    echo "3️⃣  Deploy Production Pod:"
    echo "    - Use your new template"
    echo "    - Recommended GPU: RTX 4090 or A5000 (spot instance)"
    echo "    - First start downloads model (~8GB, 5-10 mins)"
    echo ""
    echo "4️⃣  Get your server URL:"
    echo "    - Pod Dashboard → Find your pod's IP:Port"
    echo "    - Test: curl http://<pod-ip>:<port>/health"
    echo ""
    echo "5️⃣  Configure iOS App:"
    echo "    - Settings → DeepSeek-OCR URL"
    echo "    - Enter: http://<pod-ip>:<port>"
    echo ""
    echo "════════════════════════════════════════"
    echo "💰 Cost Optimization Tips:"
    echo "════════════════════════════════════════"
    echo "- Use SPOT instances (40-50% cheaper!)"
    echo "- Stop pods when not in use"
    echo "- A5000 spot = $0.19/hr (best value)"
    echo "- 100 receipts ≈ $0.25-0.50"
    echo ""
else
    echo ""
    echo "⏭️  Skipping push"
    echo "💡 To push later:"
    echo "   docker login"
    echo "   docker push ${IMAGE_NAME}"
fi

echo ""
echo "✨ Build complete!"



#!/bin/bash
# Quick build script for RunPod
# Run this directly on a RunPod instance

set -e  # Exit on error

echo "🚀 DeepSeek-OCR Docker Build on RunPod"
echo "======================================"
echo ""

# Check if we're on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "❌ This script must run on Linux (RunPod)"
    exit 1
fi

# Get Docker Hub username
read -p "Enter your Docker Hub username: " DOCKER_USERNAME
if [ -z "$DOCKER_USERNAME" ]; then
    echo "❌ Docker Hub username is required"
    exit 1
fi

IMAGE_NAME="deepseek-ocr-server"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:latest"

echo ""
echo "📦 Will build: ${FULL_IMAGE_NAME}"
echo ""

# Ask which Dockerfile
echo "Which build method?"
echo "  1) Full build (Dockerfile.deepseek) - ~10-15 minutes"
echo "  2) Pre-built vLLM base (Dockerfile.deepseek.prebuilt) - ~2-3 minutes ⭐"
read -p "Choice (1 or 2) [2]: " choice
choice=${choice:-2}

if [[ $choice == "1" ]]; then
    DOCKERFILE="Dockerfile.deepseek"
    echo "✅ Using full build"
else
    DOCKERFILE="Dockerfile.deepseek.prebuilt"
    echo "✅ Using pre-built vLLM image (faster!)"
fi

# Build
echo ""
echo "🔨 Building Docker image..."
docker build -f ${DOCKERFILE} -t ${FULL_IMAGE_NAME} .

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "✅ Build successful!"
echo ""

# Tag as latest
docker tag ${FULL_IMAGE_NAME} ${DOCKER_USERNAME}/${IMAGE_NAME}:latest

# Ask to push
read -p "📤 Push to Docker Hub now? (y/n) [y]: " push_choice
push_choice=${push_choice:-y}

if [[ $push_choice =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔐 Logging in to Docker Hub..."
    docker login
    
    if [ $? -ne 0 ]; then
        echo "❌ Docker login failed"
        exit 1
    fi
    
    echo ""
    echo "📤 Pushing ${FULL_IMAGE_NAME}..."
    docker push ${FULL_IMAGE_NAME}
    
    echo ""
    echo "✅ Push successful!"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Go to RunPod → Templates → New Template"
    echo "   2. Docker Image: ${FULL_IMAGE_NAME}"
    echo "   3. Container Disk: 20GB"
    echo "   4. Expose Port: 5003"
    echo "   5. Deploy with GPU: RTX 4090, A5000, or A6000"
    echo ""
    echo "🎉 Then use your iOS app to connect!"
else
    echo ""
    echo "⏭️  Skipping push"
    echo ""
    echo "💡 To push later:"
    echo "   docker login"
    echo "   docker push ${FULL_IMAGE_NAME}"
fi

echo ""
echo "💡 Image details:"
docker images ${FULL_IMAGE_NAME} --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"



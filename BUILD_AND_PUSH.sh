#!/bin/bash
# Quick build and push script for Receipt Tracker OCR Backend
# Usage: ./BUILD_AND_PUSH.sh [version]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
GITHUB_USERNAME="babushkai"
REPO_NAME="receipt-tracker-ios"
IMAGE_NAME="ocr-backend"
REGISTRY="ghcr.io"
FULL_IMAGE_NAME="${REGISTRY}/${GITHUB_USERNAME}/${REPO_NAME}/${IMAGE_NAME}"

# Version (use argument or default to 'dev')
VERSION="${1:-dev}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Receipt Tracker OCR - Docker Build${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if nvidia-smi is available (for GPU support)
if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✅ NVIDIA GPU detected${NC}"
    GPU_FLAG="--gpus all"
else
    echo -e "${YELLOW}⚠️  No NVIDIA GPU detected. Building without GPU support.${NC}"
    GPU_FLAG=""
fi

echo ""
echo -e "${YELLOW}📦 Building Docker image...${NC}"
echo "Image: ${FULL_IMAGE_NAME}:${VERSION}"
echo ""

# Build the image
docker buildx build \
    --platform linux/amd64 \
    --cache-from type=local,src=/tmp/docker-cache \
    --cache-to type=local,dest=/tmp/docker-cache \
    -t "${FULL_IMAGE_NAME}:${VERSION}" \
    -t "${FULL_IMAGE_NAME}:latest" \
    -f Dockerfile \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}🧪 Testing the image...${NC}"

# Run a quick health check
docker run --rm ${GPU_FLAG} -p 18000:8000 -p 15003:5003 \
    -e API_KEY_IOS=test_key_123 \
    "${FULL_IMAGE_NAME}:${VERSION}" &
CONTAINER_PID=$!

# Wait for container to start
sleep 10

# Health check
if curl -s http://localhost:18000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Health check passed!${NC}"
    # Stop the test container
    docker stop $(docker ps -q --filter ancestor="${FULL_IMAGE_NAME}:${VERSION}") > /dev/null 2>&1
else
    echo -e "${RED}❌ Health check failed!${NC}"
    docker stop $(docker ps -q --filter ancestor="${FULL_IMAGE_NAME}:${VERSION}") > /dev/null 2>&1
    exit 1
fi

echo ""
echo -e "${YELLOW}🔐 Logging in to GitHub Container Registry...${NC}"
echo "Make sure you have a GitHub token with 'write:packages' permission"
echo ""

# Check if already logged in
if docker login ${REGISTRY} --username ${GITHUB_USERNAME} --password-stdin < /dev/null 2>&1 | grep -q "Stored"; then
    echo -e "${GREEN}✅ Already logged in${NC}"
else
    echo "Enter your GitHub Personal Access Token:"
    read -s GITHUB_TOKEN
    echo ""
    
    echo "${GITHUB_TOKEN}" | docker login ${REGISTRY} --username ${GITHUB_USERNAME} --password-stdin
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Login successful!${NC}"
    else
        echo -e "${RED}❌ Login failed!${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}📤 Pushing to GitHub Container Registry...${NC}"

# Push both tags
docker push "${FULL_IMAGE_NAME}:${VERSION}"
docker push "${FULL_IMAGE_NAME}:latest"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Push successful!${NC}"
else
    echo -e "${RED}❌ Push failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✨ All done! Image published successfully${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "📦 Image available at:"
echo "   ${FULL_IMAGE_NAME}:${VERSION}"
echo "   ${FULL_IMAGE_NAME}:latest"
echo ""
echo "🚀 Pull and run with:"
echo "   docker pull ${FULL_IMAGE_NAME}:latest"
echo "   docker run --gpus all -p 8000:8000 ${FULL_IMAGE_NAME}:latest"
echo ""
echo "📚 View on GitHub:"
echo "   https://github.com/${GITHUB_USERNAME}/${REPO_NAME}/pkgs/container/${REPO_NAME}%2F${IMAGE_NAME}"
echo ""


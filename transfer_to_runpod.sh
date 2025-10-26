#!/bin/bash
# Transfer files to RunPod and build remotely
# This script helps you transfer files from macOS to RunPod
# SECURITY: This file contains examples - update with YOUR values
# DO NOT commit your actual SSH key or credentials!

echo "📤 Transfer Files to RunPod for Building"
echo "=========================================="
echo ""

# Get RunPod details
read -p "Enter your RunPod SSH host (e.g., root@157.157.221.29): " RUNPOD_HOST
read -p "Enter your RunPod SSH port (default: 22): " RUNPOD_PORT
RUNPOD_PORT=${RUNPOD_PORT:-22}

# SSH key path (customize if needed)
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/runpod_key}"

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "⚠️  SSH key not found at: $SSH_KEY_PATH"
    echo "💡 Using default SSH authentication"
    SSH_KEY_PARAM=""
else
    SSH_KEY_PARAM="-i $SSH_KEY_PATH"
fi

echo ""
echo "📁 Files to transfer:"
echo "  - deepseek_ocr_server.py"
echo "  - Dockerfile.deepseek.prebuilt"
echo "  - (optional) Dockerfile.deepseek"
echo ""

# Create remote directory
echo "📂 Creating remote directory..."
ssh -p ${RUNPOD_PORT} ${SSH_KEY_PARAM} ${RUNPOD_HOST} "mkdir -p /workspace/deepseek-build"

# Transfer files
echo "📤 Transferring files..."
scp -P ${RUNPOD_PORT} ${SSH_KEY_PARAM} \
    deepseek_ocr_server.py \
    Dockerfile.deepseek.prebuilt \
    Dockerfile.deepseek \
    ${RUNPOD_HOST}:/workspace/deepseek-build/

echo ""
echo "✅ Files transferred!"
echo ""
echo "🚀 Next, SSH into RunPod and build:"
echo ""
echo "ssh -p ${RUNPOD_PORT} ${SSH_KEY_PARAM} ${RUNPOD_HOST}"
echo ""
echo "Then run these commands:"
echo "════════════════════════════════════════"
echo "cd /workspace/deepseek-build"
echo ""
echo "# Build (using pre-built vLLM - fastest!)"
echo "docker build -f Dockerfile.deepseek.prebuilt -t deepseek-ocr-server:latest ."
echo ""
echo "# Tag for Docker Hub"
echo "docker tag deepseek-ocr-server:latest YOUR_USERNAME/deepseek-ocr-server:latest"
echo ""
echo "# Login and push"
echo "docker login"
echo "docker push YOUR_USERNAME/deepseek-ocr-server:latest"
echo "════════════════════════════════════════"



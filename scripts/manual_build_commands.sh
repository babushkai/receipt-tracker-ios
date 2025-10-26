#!/bin/bash
# Manual build commands for RunPod web terminal
# If SSH automation fails, use these commands in RunPod's web terminal

set -e

echo "📦 Installing git..."
apt-get update -qq && apt-get install -y -qq git curl

echo "📥 Cloning repository..."
cd /workspace
git clone https://github.com/${GITHUB_REPOSITORY:-babushkai/receipt-tracker-ios}.git build
cd build
git checkout ${GITHUB_SHA:-main}

echo "🔨 Building Docker image..."
docker build -f Dockerfile.deepseek.prebuilt -t temp-build:latest .

echo "🏷️  Tagging images..."
docker tag temp-build:latest ghcr.io/${GITHUB_REPOSITORY:-babushkai/receipt-tracker-ios}/deepseek-ocr:latest
docker tag temp-build:latest ghcr.io/${GITHUB_REPOSITORY:-babushkai/receipt-tracker-ios}/deepseek-ocr:${GITHUB_SHA:0:8}

echo "🔐 Logging in to GitHub Container Registry..."
echo "${GITHUB_TOKEN}" | docker login ghcr.io -u ${GITHUB_ACTOR:-babushkai} --password-stdin

echo "📤 Pushing images..."
docker push ghcr.io/${GITHUB_REPOSITORY:-babushkai/receipt-tracker-ios}/deepseek-ocr:latest
docker push ghcr.io/${GITHUB_REPOSITORY:-babushkai/receipt-tracker-ios}/deepseek-ocr:${GITHUB_SHA:0:8}

echo "✅ Build complete!"
echo "📊 Image size:"
docker images ghcr.io/${GITHUB_REPOSITORY:-babushkai/receipt-tracker-ios}/deepseek-ocr:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"


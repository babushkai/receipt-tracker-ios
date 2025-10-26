#!/bin/bash
# Setup script for DeepSeek-OCR with vLLM on RunPod
# Based on: https://docs.vllm.ai/projects/recipes/en/latest/DeepSeek/DeepSeek-OCR.html

echo "🚀 Setting up DeepSeek-OCR with vLLM on RunPod"
echo "=" * 70

# Update system packages
echo "📦 Updating system packages..."
apt-get update && apt-get install -y python3-pip python3-venv

# Create virtual environment
echo "🐍 Creating Python virtual environment..."
python3 -m venv /workspace/deepseek_env
source /workspace/deepseek_env/bin/activate

# Install dependencies
echo "📥 Installing Flask and Pillow..."
pip install flask pillow

# Install vLLM from nightly build
echo "🚀 Installing vLLM (this will take several minutes)..."
pip install -U vllm --pre --extra-index-url https://wheels.vllm.ai/nightly

echo ""
echo "✅ Installation complete!"
echo ""
echo "💡 To start the server, run:"
echo "   source /workspace/deepseek_env/bin/activate"
echo "   python3 deepseek_ocr_server.py"
echo ""
echo "📝 The server will run on port 5003"
echo "💡 Make sure to expose this port in your RunPod configuration"
echo ""
echo "🔗 Documentation: https://docs.vllm.ai/projects/recipes/en/latest/DeepSeek/DeepSeek-OCR.html"



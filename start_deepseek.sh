#!/bin/bash

echo "🚀 Starting DeepSeek-OCR Server (vLLM-powered) for Receipt Tracker"
echo ""
echo "⚠️  IMPORTANT: DeepSeek-OCR with vLLM requires significant computational resources"
echo "   - Required: CUDA-capable GPU with 24GB+ VRAM"
echo "   - vLLM does NOT support CPU inference"
echo "   - Recommended: Python 3.9-3.11, CUDA 12.1+"
echo ""

# Check if virtual environment exists
if [ ! -d "deepseek_env" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv deepseek_env
    
    echo "📥 Installing dependencies..."
    source deepseek_env/bin/activate
    
    # Check for CUDA
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "❌ ERROR: vLLM does not support macOS"
        echo "💡 DeepSeek-OCR with vLLM requires Linux with CUDA GPU"
        echo "💡 Consider using RunPod, Modal, or other GPU cloud providers"
        exit 1
    fi
    
    # Install basic requirements
    pip install flask pillow
    
    # Install vLLM from nightly (until v0.11.1 release)
    echo "🚀 Installing vLLM (this may take a few minutes)..."
    pip install -U vllm --pre --extra-index-url https://wheels.vllm.ai/nightly
    
    echo "✅ Installation complete!"
else
    source deepseek_env/bin/activate
fi

echo ""
echo "🔥 Starting server on http://localhost:5003"
echo "💡 This may take a minute while the model loads..."
echo "💡 First run will download model weights (~8GB)"
echo ""
echo "📝 Test the server with:"
echo "   curl http://localhost:5003/health"
echo ""
echo "🔗 Based on: https://docs.vllm.ai/projects/recipes/en/latest/DeepSeek/DeepSeek-OCR.html"
echo ""
echo "⏹  Press Ctrl+C to stop the server"
echo ""

python3 deepseek_ocr_server.py


#!/bin/bash

echo "🚀 Starting olmOCR-7B Server Setup..."
echo ""

# Check if virtual environment exists
if [ ! -d "olmocr_env" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv olmocr_env
    echo "✅ Virtual environment created"
    echo ""
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source olmocr_env/bin/activate

# Check if dependencies are installed
if ! python3 -c "import transformers" 2>/dev/null; then
    echo "📥 Installing olmOCR dependencies..."
    echo "⏳ This may take 10-15 minutes on first run..."
    echo "📦 Will download PyTorch (~2GB) and Transformers"
    echo ""
    
    if pip install -r olmocr_requirements.txt; then
        echo ""
        echo "✅ Dependencies installed successfully!"
        echo ""
    else
        echo ""
        echo "❌ Failed to install dependencies!"
        echo "💡 Try manually: pip install torch transformers accelerate"
        exit 1
    fi
fi

# Start the server
echo "🚀 Starting olmOCR-7B server..."
echo "📍 Server will be available at: http://localhost:5002"
echo ""
echo "💡 Press Ctrl+C to stop the server"
echo "⏳ First request: Will download ~14GB model (one-time only)"
echo "⏱️  Initialization: ~2-3 minutes on first request"
echo "🖥️  Performance: GPU highly recommended for speed"
echo ""
echo "================================================================"
python3 olmocr_server.py


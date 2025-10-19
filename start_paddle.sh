#!/bin/bash

echo "🚀 Starting EasyOCR Server Setup..."
echo ""

# Check if virtual environment exists
if [ ! -d "paddle_env" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv paddle_env
    echo "✅ Virtual environment created"
    echo ""
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source paddle_env/bin/activate

# Check if dependencies are installed
if ! python3 -c "import easyocr" 2>/dev/null; then
    echo "📥 Installing EasyOCR dependencies..."
    echo "⏳ This may take 5-10 minutes on first run..."
    echo "📦 Will download PyTorch (~500MB) and EasyOCR models"
    echo ""
    
    if pip install -r paddle_requirements.txt; then
        echo ""
        echo "✅ Dependencies installed successfully!"
        echo ""
    else
        echo ""
        echo "❌ Failed to install dependencies!"
        echo "💡 Try manually: pip install flask easyocr torch torchvision"
        exit 1
    fi
fi

# Start the server
echo "🚀 Starting EasyOCR server..."
echo "📍 Server will be available at: http://localhost:5000"
echo ""
echo "💡 Press Ctrl+C to stop the server"
echo "⏳ First run: EasyOCR will download language models (~100MB)"
echo ""
echo "================================================================"
python3 easyocr_server.py


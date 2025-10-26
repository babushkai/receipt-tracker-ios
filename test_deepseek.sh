#!/bin/bash
# Quick test script for DeepSeek-OCR server (vLLM-based)

echo "🧪 Testing DeepSeek-OCR Server (vLLM)"
echo "======================================"
echo ""

# Check if server is running
echo "1️⃣ Checking server health..."
response=$(curl -s http://localhost:5003/health)
echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
echo ""

# Check status
if echo "$response" | grep -q '"model_loaded":true'; then
    echo "✅ Server is ready!"
    echo ""
    echo "2️⃣ You can now:"
    echo "   - Configure iOS app Settings → Server URLs"
    echo "   - Set DeepSeek-OCR URL to: http://localhost:5003"
    echo "   - Start scanning receipts!"
    echo ""
    echo "🚀 Using vLLM for optimized inference"
    echo "⚡ Batch processing supported and recommended"
elif echo "$response" | grep -q '"model_loaded":false'; then
    echo "⏳ Server is running but model is still loading..."
    echo ""
    echo "💡 First time setup downloads ~8GB model (takes 3-5 minutes)"
    echo "   vLLM will compile kernels on first run"
    echo ""
    echo "   Wait and run this script again: ./test_deepseek.sh"
else
    echo "❌ Server is not responding"
    echo ""
    echo "💡 Start the server with: ./start_deepseek.sh"
    echo "⚠️  Remember: vLLM requires Linux + CUDA GPU"
fi

echo ""
echo "📊 Server Info:"
echo "   - Engine: $(echo "$response" | grep -o '"engine":"[^"]*"')"
echo "   - Model: $(echo "$response" | grep -o '"model":"[^"]*"')"




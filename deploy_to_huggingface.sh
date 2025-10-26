#!/bin/bash

echo "🤗 DeepSeek-OCR → Hugging Face Spaces Deployment"
echo "================================================"
echo ""

# Check if Hugging Face CLI is installed
if ! command -v huggingface-cli &> /dev/null; then
    echo "📦 Installing Hugging Face CLI..."
    pip install huggingface_hub
fi

echo "🔑 Step 1: Login to Hugging Face"
echo "   Go to: https://huggingface.co/settings/tokens"
echo "   Create a WRITE token if you haven't already"
echo ""
echo "   Running login..."
huggingface-cli login

echo ""
echo "🏗️  Step 2: Create your Space"
echo "   1. Go to: https://huggingface.co/new-space"
echo "   2. Fill in:"
echo "      - Space name: deepseek-ocr-receipt (or your choice)"
echo "      - SDK: Gradio"
echo "      - Hardware: ZeroGPU ⚡ (IMPORTANT!)"
echo "      - Visibility: Public (for free GPU)"
echo "   3. Click 'Create Space'"
echo ""
read -p "   Press Enter after you've created the Space..."

echo ""
read -p "📝 Enter your Hugging Face username: " HF_USERNAME
read -p "📝 Enter your Space name (e.g., deepseek-ocr-receipt): " SPACE_NAME

echo ""
echo "📤 Step 3: Uploading files to HF Space..."
cd /Users/dsuke/Projects/dev/receipt/huggingface_space

huggingface-cli upload $HF_USERNAME/$SPACE_NAME . --repo-type=space

echo ""
echo "✅ Deployment Complete!"
echo "================================================"
echo ""
echo "🌐 Your Space URL:"
echo "   https://huggingface.co/spaces/$HF_USERNAME/$SPACE_NAME"
echo ""
echo "🔗 API Endpoint:"
echo "   https://$HF_USERNAME-$(echo $SPACE_NAME | tr '_' '-').hf.space"
echo ""
echo "⏳ Next Steps:"
echo "   1. Visit your Space URL (build takes 5-10 min first time)"
echo "   2. Once 'Running', test the web interface"
echo "   3. Add API URL to iOS app: Settings → Server URLs → DeepSeek-OCR"
echo ""
echo "📱 iOS App Configuration:"
echo "   URL: https://$HF_USERNAME-$(echo $SPACE_NAME | tr '_' '-').hf.space"
echo ""
echo "🎉 Happy scanning!"




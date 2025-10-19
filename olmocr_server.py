#!/usr/bin/env python3
"""
olmOCR Server for ReceiptTracker
Provides REST API for document OCR using Allen AI's olmOCR-7B model
Based on: https://huggingface.co/allenai/olmOCR-7B-0225-preview
"""

from flask import Flask, request, jsonify
import torch
import base64
from io import BytesIO
from PIL import Image
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Global variables for model and processor
model = None
processor = None
device = None

def initialize_model():
    """Initialize olmOCR model on first request (lazy loading)"""
    global model, processor, device
    
    if model is not None:
        return
    
    logging.info("🔧 Initializing olmOCR-7B model (this may take a few minutes)...")
    logging.info("📥 Downloading model weights (~14GB)...")
    
    try:
        from transformers import AutoProcessor, Qwen2VLForConditionalGeneration
        
        # Determine device
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        logging.info(f"🖥️  Using device: {device}")
        
        if device.type == "cpu":
            logging.warning("⚠️  Running on CPU - this will be slower. GPU recommended.")
        
        # Load model
        model = Qwen2VLForConditionalGeneration.from_pretrained(
            "allenai/olmOCR-7B-0225-preview",
            torch_dtype=torch.bfloat16 if device.type == "cuda" else torch.float32
        ).eval()
        model.to(device)
        
        # Load processor
        processor = AutoProcessor.from_pretrained("Qwen/Qwen2-VL-7B-Instruct")
        
        logging.info("✅ olmOCR model loaded successfully!")
        
    except Exception as e:
        logging.error(f"❌ Failed to initialize model: {e}")
        raise

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'service': 'olmOCR Server',
        'version': '1.0.0',
        'model': 'allenai/olmOCR-7B-0225-preview',
        'device': str(device) if device else 'not_initialized'
    })

@app.route('/ocr', methods=['POST'])
def perform_ocr():
    """
    Perform OCR on uploaded image using olmOCR
    
    Request body:
    {
        "image": "base64_encoded_image_data",
        "prompt": "optional custom prompt" (defaults to basic OCR)
    }
    
    Response:
    {
        "success": true,
        "text": "extracted text",
        "confidence": 0.95
    }
    """
    try:
        # Initialize model on first request
        if model is None:
            initialize_model()
        
        data = request.get_json()
        
        if 'image' not in data:
            return jsonify({
                'success': False,
                'error': 'No image data provided'
            }), 400
        
        # Decode base64 image
        image_data = base64.b64decode(data['image'])
        image = Image.open(BytesIO(image_data))
        
        # Resize to optimal size (longest dimension = 1024px as per olmOCR specs)
        max_dim = max(image.size)
        if max_dim > 1024:
            scale = 1024 / max_dim
            new_size = (int(image.size[0] * scale), int(image.size[1] * scale))
            image = image.resize(new_size, Image.Resampling.LANCZOS)
            logging.info(f"📐 Resized image to {new_size}")
        
        # Convert to RGB if needed
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Build prompt (simple OCR prompt for receipts)
        custom_prompt = data.get('prompt', 
            "Extract all text from this receipt image in the exact order it appears. "
            "Include merchant name, date, items, prices, and total. "
            "Preserve the original formatting and layout."
        )
        
        logging.info(f"🔍 Processing image with olmOCR...")
        
        # Build message with image
        image_base64 = base64.b64encode(BytesIO().getvalue()).decode()
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": custom_prompt},
                    {"type": "image", "image": image},
                ],
            }
        ]
        
        # Apply chat template and processor
        text = processor.apply_chat_template(
            messages, 
            tokenize=False, 
            add_generation_prompt=True
        )
        
        inputs = processor(
            text=[text],
            images=[image],
            padding=True,
            return_tensors="pt",
        )
        inputs = {key: value.to(device) for (key, value) in inputs.items()}
        
        # Generate output
        logging.info("🤖 Generating OCR output...")
        with torch.no_grad():
            output = model.generate(
                **inputs,
                temperature=0.3,  # Lower temperature for more deterministic output
                max_new_tokens=2048,  # Allow longer outputs for receipts
                num_return_sequences=1,
                do_sample=True,
            )
        
        # Decode output
        prompt_length = inputs["input_ids"].shape[1]
        new_tokens = output[:, prompt_length:]
        text_output = processor.tokenizer.batch_decode(
            new_tokens, 
            skip_special_tokens=True
        )[0]
        
        logging.info(f"✅ OCR complete! Extracted {len(text_output)} characters")
        
        return jsonify({
            'success': True,
            'text': text_output,
            'confidence': 0.95,  # olmOCR is highly confident
            'model': 'olmOCR-7B-0225-preview',
            'length': len(text_output)
        })
        
    except Exception as e:
        logging.error(f"❌ OCR error: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    print("=" * 70)
    print("🚀 Starting olmOCR Server")
    print("=" * 70)
    print("📍 Server will run on: http://localhost:5002")
    print("🔍 Endpoints:")
    print("   - GET  /health  → Health check")
    print("   - POST /ocr     → OCR extraction")
    print("")
    print("📚 Model: allenai/olmOCR-7B-0225-preview (7B parameters)")
    print("🧠 Based on: Qwen2-VL-7B-Instruct")
    print("📄 Optimized for: Document OCR (receipts, invoices, forms)")
    print("")
    print("⚠️  Note: First request will download ~14GB of model weights")
    print("⏱️  Initialization takes ~2-3 minutes on first run")
    print("💡 GPU highly recommended for faster inference")
    print("=" * 70)
    
    app.run(host='0.0.0.0', port=5002, debug=False)


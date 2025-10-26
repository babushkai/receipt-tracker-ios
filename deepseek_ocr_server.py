#!/usr/bin/env python3
"""
DeepSeek-OCR Server for ReceiptTracker (vLLM-based)
Provides a REST API endpoint for OCR using DeepSeek-OCR with vLLM
Note: Requires GPU with CUDA support for optimal performance
Based on: https://docs.vllm.ai/projects/recipes/en/latest/DeepSeek/DeepSeek-OCR.html
"""

from flask import Flask, request, jsonify
import base64
from PIL import Image
import io
import logging
import os
import requests
from urllib.parse import urlparse

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Initialize DeepSeek-OCR with vLLM
logging.info("🔧 Initializing DeepSeek-OCR model with vLLM...")

try:
    import os
    # Disable HF_TRANSFER which causes issues
    os.environ['HF_HUB_ENABLE_HF_TRANSFER'] = '0'
    
    from vllm import LLM, SamplingParams
    from vllm.model_executor.models.deepseek_ocr import NGramPerReqLogitsProcessor
    
    # Use local model cache if available, otherwise download from HuggingFace
    model_path = "./model_cache/models--deepseek-ai--DeepSeek-OCR/snapshots/2c968b433af61a059311cbf8997765023806a24d"
    if not os.path.exists(model_path):
        model_path = "deepseek-ai/DeepSeek-OCR"
    
    # Create model instance using vLLM (official configuration)
    # Flash Attention is automatically enabled by vLLM for supported GPUs
    llm = LLM(
        model=model_path,
        enable_prefix_caching=False,  # Not needed for OCR tasks
        mm_processor_cache_gb=0,  # Save memory
        logits_processors=[NGramPerReqLogitsProcessor],  # Important for markdown table generation
    )
    
    logging.info("✅ DeepSeek-OCR model initialized successfully with vLLM!")
    logging.info("🚀 Using vLLM for optimized inference performance")
    MODEL_LOADED = True
except Exception as e:
    logging.error(f"❌ Failed to load DeepSeek-OCR model: {str(e)}")
    logging.error("💡 Make sure you have installed vLLM: pip install vllm --pre --extra-index-url https://wheels.vllm.ai/nightly")
    MODEL_LOADED = False
    llm = None

def load_image(image_input):
    """
    Load image from URL or base64 string
    
    Args:
        image_input: URL string or base64-encoded image data
        
    Returns:
        PIL Image object
    """
    # Check if it's a URL
    if isinstance(image_input, str) and (image_input.startswith('http://') or image_input.startswith('https://')):
        logging.info(f"Loading image from URL: {image_input[:100]}...")
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        response = requests.get(image_input, headers=headers, timeout=30)
        response.raise_for_status()
        image = Image.open(io.BytesIO(response.content)).convert("RGB")
    else:
        # Assume it's base64
        logging.info("Loading image from base64 data...")
        image_data = base64.b64decode(image_input)
        image = Image.open(io.BytesIO(image_data)).convert("RGB")
    
    return image

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok' if MODEL_LOADED else 'error',
        'service': 'DeepSeek-OCR Server (vLLM)',
        'version': '2.0.0',
        'model_loaded': MODEL_LOADED,
        'engine': 'vLLM',
        'model': 'deepseek-ai/DeepSeek-OCR'
    })

@app.route('/ocr', methods=['POST'])
def perform_ocr():
    """
    Perform OCR on uploaded image using DeepSeek-OCR with vLLM
    
    Request body:
    {
        "image": "https://example.com/image.jpg" OR "base64_encoded_image_data",
        "prompt": "custom prompt" (optional, defaults to "Free OCR.")
    }
    
    Response:
    {
        "success": true,
        "text": "extracted text"
    }
    """
    if not MODEL_LOADED:
        return jsonify({
            'success': False,
            'error': 'DeepSeek-OCR model not loaded. Please check server logs.'
        }), 503
    
    try:
        data = request.get_json()
        
        if 'image' not in data:
            return jsonify({
                'success': False,
                'error': 'No image data provided'
            }), 400
        
        # Load image from URL or base64
        image = load_image(data['image'])
        
        # Get custom prompt or use default structured receipt extraction
        custom_prompt = data.get('prompt', '''Extract all information from this receipt and return it as a JSON array with the following structure:
[
  {
    "name": "merchant name",
    "address": "street address",
    "city": "city with postal code",
    "email": "email if available"
  },
  {
    "invoice": {
      "number": "invoice number",
      "date": "DD.MM.YYYY",
      "time": "HH:MM:SS",
      "table": "table number if available"
    }
  },
  {
    "item": "item name",
    "quantity": number,
    "unit_price": "price with currency",
    "total_price": "total with currency"
  },
  // ... more items
  {
    "summary": {
      "total": "total with currency",
      "tax_included": "tax info"
    }
  },
  {
    "server": "server name if available"
  },
  {
    "contact": {
      "phone": "phone number",
      "fax": "fax number",
      "email": "email"
    }
  }
]
Extract ALL items, prices, and information visible on the receipt.''')
        prompt = f"<image>\n{custom_prompt}"
        
        logging.info(f"Processing image with vLLM...")
        logging.info(f"Prompt: {prompt}")
        
        # Prepare input for vLLM
        model_input = [{
            "prompt": prompt,
            "multi_modal_data": {"image": image}
        }]
        
        # Configure sampling parameters with ngram logit processor
        sampling_params = SamplingParams(
            temperature=0.0,  # Deterministic for OCR
            max_tokens=8192,  # Allow long outputs for documents
            # ngram logit processor args (improves markdown table generation)
            extra_args=dict(
                ngram_size=30,
                window_size=90,
                whitelist_token_ids={128821, 128822},  # <td>, </td>
            ),
            skip_special_tokens=False,
        )
        
        # Generate output using vLLM
        model_outputs = llm.generate(model_input, sampling_params)
        
        # Extract the generated text
        result = model_outputs[0].outputs[0].text
        
        if not result:
            return jsonify({
                'success': False,
                'error': 'No text detected in image'
            }), 200
        
        logging.info(f"✅ Extracted {len(result)} characters")
        
        # Try to parse as JSON
        import json
        import re
        
        structured_data = None
        try:
            # Remove markdown code blocks if present
            json_text = result
            if '```json' in json_text:
                json_text = re.search(r'```json\s*\n(.*?)\n```', json_text, re.DOTALL).group(1)
            elif '```' in json_text:
                json_text = re.search(r'```\s*\n(.*?)\n```', json_text, re.DOTALL).group(1)
            
            # Parse JSON
            structured_data = json.loads(json_text)
            logging.info("✅ Successfully parsed structured JSON data")
        except Exception as e:
            logging.warning(f"Could not parse as JSON: {e}")
            # Fall back to returning raw text
            structured_data = None
        
        response = {
            'success': True,
            'engine': 'vLLM',
            'model': 'deepseek-ai/DeepSeek-OCR'
        }
        
        # Return structured data if available, otherwise raw text
        if structured_data:
            response['structured_data'] = structured_data
            response['raw_text'] = result  # Keep raw text for reference
        else:
            response['text'] = result
        
        return jsonify(response)
        
    except Exception as e:
        logging.error(f"OCR error: {str(e)}")
        import traceback
        logging.error(traceback.format_exc())
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/ocr/batch', methods=['POST'])
def perform_batch_ocr():
    """
    Perform OCR on multiple images using vLLM batch processing
    
    Request body:
    {
        "images": ["https://url1.com/img.jpg", "https://url2.com/img.jpg", ...] OR ["base64_1", "base64_2", ...],
        "prompt": "custom prompt" (optional)
    }
    
    Response:
    {
        "success": true,
        "results": [{"success": true, "text": "..."}, ...],
        "total": 3,
        "successful": 3
    }
    """
    if not MODEL_LOADED:
        return jsonify({
            'success': False,
            'error': 'DeepSeek-OCR model not loaded. Please check server logs.'
        }), 503
    
    try:
        data = request.get_json()
        images_b64 = data.get('images', [])
        custom_prompt = data.get('prompt', 'Free OCR.')
        
        if not images_b64:
            return jsonify({
                'success': False,
                'error': 'No images provided'
            }), 400
        
        logging.info(f"Processing {len(images_b64)} images in batch with vLLM...")
        
        # Load all images (from URLs or base64)
        images = []
        for idx, img_input in enumerate(images_b64):
            try:
                image = load_image(img_input)
                images.append(image)
            except Exception as e:
                logging.error(f"Failed to load image {idx + 1}: {str(e)}")
                return jsonify({
                    'success': False,
                    'error': f'Failed to load image {idx + 1}: {str(e)}'
                }), 400
        
        # Prepare batched input for vLLM (vLLM handles batching efficiently!)
        prompt = f"<image>\n{custom_prompt}"
        model_inputs = [
            {
                "prompt": prompt,
                "multi_modal_data": {"image": img}
            }
            for img in images
        ]
        
        # Configure sampling parameters
        sampling_params = SamplingParams(
            temperature=0.0,
            max_tokens=8192,
            extra_args=dict(
                ngram_size=30,
                window_size=90,
                whitelist_token_ids={128821, 128822},
            ),
            skip_special_tokens=False,
        )
        
        # Generate outputs in batch (vLLM is optimized for this!)
        model_outputs = llm.generate(model_inputs, sampling_params)
        
        # Extract results
        results = []
        for idx, output in enumerate(model_outputs):
            text = output.outputs[0].text
            results.append({
                'success': True,
                'text': text,
                'length': len(text)
            })
            logging.info(f"Image {idx + 1}/{len(images)}: Extracted {len(text)} characters")
        
        successful = sum(1 for r in results if r.get('success', False))
        
        logging.info(f"✅ Batch OCR complete: {successful}/{len(images)} successful")
        
        return jsonify({
            'success': True,
            'results': results,
            'total': len(images),
            'successful': successful,
            'engine': 'vLLM'
        })
        
    except Exception as e:
        logging.error(f"Batch OCR error: {str(e)}")
        import traceback
        logging.error(traceback.format_exc())
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    print("=" * 70)
    print("🚀 Starting DeepSeek-OCR Server (vLLM-powered)")
    print("=" * 70)
    
    if MODEL_LOADED:
        print("✅ DeepSeek-OCR model loaded successfully with vLLM")
        print("🚀 Using vLLM for optimized inference (much faster!)")
        print("⚡ Supports efficient batch processing")
    else:
        print("❌ Failed to load DeepSeek-OCR model")
        print("💡 Check the logs above for error details")
        print("💡 Install vLLM: pip install vllm --pre --extra-index-url https://wheels.vllm.ai/nightly")
    
    print("")
    print("📍 Server will run on: http://localhost:5003")
    print("🔍 Endpoints:")
    print("   - GET  /health       → Health check")
    print("   - POST /ocr          → Single image OCR")
    print("   - POST /ocr/batch    → Batch image OCR (optimized!)")
    print("")
    print("📝 Prompts:")
    print("   - 'Free OCR.' → General OCR (default)")
    print("   - Custom prompts supported for specific tasks")
    print("")
    print("💡 DeepSeek-OCR excels at:")
    print("   - Document understanding & structure preservation")
    print("   - Markdown output for receipts, invoices, forms")
    print("   - Table detection and formatting")
    print("   - Multilingual text recognition")
    print("")
    print("🔗 Based on: https://docs.vllm.ai/projects/recipes/en/latest/DeepSeek/DeepSeek-OCR.html")
    print("=" * 70)
    
    app.run(host='0.0.0.0', port=5003, debug=False)


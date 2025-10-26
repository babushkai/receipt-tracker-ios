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
import json

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# JSON Schema for structured receipt output
# https://github.com/search?q=repo%3Avllm-project%2Fvllm%20StructuredOutputsParams&type=code
RECEIPT_JSON_SCHEMA = {
    "type": "array",
    "items": {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "address": {"type": "string"},
            "city": {"type": "string"},
            "email": {"type": "string"},
            "invoice": {
                "type": "object",
                "properties": {
                    "number": {"type": "string"},
                    "date": {"type": "string"},
                    "time": {"type": "string"},
                    "table": {"type": "string"}
                }
            },
            "item": {"type": "string"},
            "quantity": {"type": "integer"},
            "unit_price": {"type": "string"},
            "total_price": {"type": "string"},
            "summary": {
                "type": "object",
                "properties": {
                    "total": {"type": "string"},
                    "tax_included": {"type": "string"}
                }
            },
            "server": {"type": "string"},
            "contact": {
                "type": "object",
                "properties": {
                    "mwst_number": {"type": "string"},
                    "phone": {"type": "string"},
                    "fax": {"type": "string"},
                    "email": {"type": "string"}
                }
            },
            "conversion": {
                "type": "object",
                "properties": {
                    "currency": {"type": "string"},
                    "amount": {"type": "string"}
                }
            }
        }
    }
}

# Initialize DeepSeek-OCR with vLLM
logging.info("🔧 Initializing DeepSeek-OCR model with vLLM...")

try:
    import os
    # Disable HF_TRANSFER which causes issues
    os.environ['HF_HUB_ENABLE_HF_TRANSFER'] = '0'
    
    from vllm import LLM, SamplingParams, StructuredOutputsParams
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
        
        # Get custom prompt or use default
        custom_text = data.get('prompt', 'Extract all text and information from this receipt.')
        
        # Remove any existing <image> tokens from custom text to avoid duplicates
        custom_text = custom_text.replace('<image>', '').strip()
        
        # Build prompt: exactly ONE <image> token followed by the instruction
        prompt = f"<image>\n{custom_text}"
        
        # Validate prompt format
        image_token_count = prompt.count('<image>')
        if image_token_count != 1:
            logging.error(f"Invalid prompt: found {image_token_count} <image> tokens, expected 1")
            logging.error(f"Prompt: {repr(prompt)}")
            return jsonify({
                'success': False,
                'error': f'Invalid prompt format: found {image_token_count} <image> tokens, expected 1'
            }), 400
        
        logging.info(f"Processing image with vLLM (guided JSON)...")
        logging.info(f"Prompt: {prompt}")
        
        # Prepare input for vLLM
        model_input = [{
            "prompt": prompt,
            "multi_modal_data": {"image": image}
        }]
        
        # Configure sampling parameters with guided JSON output
        sampling_params = SamplingParams(
            temperature=0.0,  # Deterministic for OCR
            max_tokens=8192,  # Allow long outputs for documents
            structured_outputs=StructuredOutputsParams(json=RECEIPT_JSON_SCHEMA),  # Force valid JSON output
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
        
        # Extract the generated text (should be valid JSON due to guided_json)
        result = model_outputs[0].outputs[0].text
        
        if not result:
            return jsonify({
                'success': False,
                'error': 'No text detected in image'
            }), 200
        
        logging.info(f"✅ Extracted {len(result)} characters")
        
        # Parse JSON (guided_json ensures valid JSON output)
        try:
            structured_data = json.loads(result)
            logging.info("✅ Successfully parsed structured JSON data")
            
            return jsonify({
                'success': True,
                'engine': 'vLLM',
                'model': 'deepseek-ai/DeepSeek-OCR',
                'structured_data': structured_data,
                'raw_text': result  # Keep raw JSON string for reference
            })
            
        except json.JSONDecodeError as e:
            logging.error(f"JSON parsing failed (should not happen with guided_json): {e}")
            # Fallback if guided_json somehow fails
            return jsonify({
                'success': True,
                'engine': 'vLLM',
                'model': 'deepseek-ai/DeepSeek-OCR',
                'text': result,
                'warning': 'JSON parsing failed'
            })
        
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
        # Remove any existing <image> tokens to avoid duplicates
        custom_prompt = custom_prompt.replace('<image>', '').strip()
        prompt = f"<image>\n{custom_prompt}"
        
        logging.info(f"Batch prompt: {prompt}")
        
        model_inputs = [
            {
                "prompt": prompt,
                "multi_modal_data": {"image": img}
            }
            for img in images
        ]
        
        # Configure sampling parameters with guided JSON
        sampling_params = SamplingParams(
            temperature=0.0,
            max_tokens=8192,
            guided_json=RECEIPT_JSON_SCHEMA,  # Force valid JSON output
            extra_args=dict(
                ngram_size=30,
                window_size=90,
                whitelist_token_ids={128821, 128822},
            ),
            skip_special_tokens=False,
        )
        
        # Generate outputs in batch (vLLM is optimized for this!)
        model_outputs = llm.generate(model_inputs, sampling_params)
        
        # Extract results and parse JSON
        results = []
        for idx, output in enumerate(model_outputs):
            text = output.outputs[0].text
            
            # Parse JSON (guided_json ensures valid JSON)
            try:
                structured_data = json.loads(text)
                results.append({
                    'success': True,
                    'structured_data': structured_data,
                    'raw_text': text
                })
                logging.info(f"Image {idx + 1}/{len(images)}: ✅ Parsed JSON ({len(text)} chars)")
            except json.JSONDecodeError as e:
                logging.warning(f"Image {idx + 1}/{len(images)}: JSON parse failed: {e}")
                results.append({
                    'success': True,
                    'text': text,
                    'warning': 'JSON parsing failed'
                })
        
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


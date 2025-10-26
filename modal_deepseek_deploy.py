"""
Modal.com Serverless Deployment for DeepSeek-OCR
Automatically scales to zero when not in use - only pay for actual processing time
Deploy with: modal deploy modal_deepseek_deploy.py
"""

import modal
import base64
from io import BytesIO

# Create Modal app
app = modal.App("deepseek-ocr-receipt")

# Define container image with all dependencies
deepseek_image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("git")
    .pip_install(
        "transformers>=4.46.3",
        "tokenizers>=0.20.3",
        "torch>=2.6.0",
        "torchvision>=0.21.0",
        "Pillow",
        "numpy",
        "einops",
        "easydict",
        "addict",
    )
    # Flash attention for speed (optional, may fail on some systems)
    .run_commands("pip install flash-attn==2.7.3 --no-build-isolation || true")
)

# Model caching - downloads once, reuses across invocations
MODEL_NAME = "deepseek-ai/DeepSeek-OCR"

@app.cls(
    image=deepseek_image,
    gpu="A100",  # Use A100 GPU - can change to "A10G" for cheaper option
    timeout=300,  # 5 minute timeout
    container_idle_timeout=60,  # Keep warm for 1 minute
)
class DeepSeekOCRModel:
    @modal.build()
    def download_model(self):
        """Download model during build phase"""
        from transformers import AutoModel, AutoTokenizer
        
        print(f"Downloading {MODEL_NAME}...")
        AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
        AutoModel.from_pretrained(
            MODEL_NAME,
            trust_remote_code=True,
            use_safetensors=True
        )
        print("Model downloaded successfully!")
    
    @modal.enter()
    def load_model(self):
        """Load model when container starts"""
        import torch
        from transformers import AutoModel, AutoTokenizer
        
        print("Loading DeepSeek-OCR model...")
        self.tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
        self.model = AutoModel.from_pretrained(
            MODEL_NAME,
            _attn_implementation='flash_attention_2',
            trust_remote_code=True,
            use_safetensors=True
        )
        self.model = self.model.eval().cuda().to(torch.bfloat16)
        print("Model loaded and ready!")
    
    @modal.method()
    def process_receipt(self, image_base64: str, mode: str = "base") -> dict:
        """Process a single receipt image"""
        import tempfile
        import os
        from PIL import Image
        
        try:
            # Decode image
            image_data = base64.b64decode(image_base64)
            image = Image.open(BytesIO(image_data))
            
            # Save to temp file
            with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp:
                image.save(tmp.name, format='JPEG', quality=95)
                image_file = tmp.name
            
            # Configure based on mode
            mode_configs = {
                'tiny': (512, 512, False),
                'small': (640, 640, False),
                'base': (1024, 1024, False),
                'large': (1280, 1280, False),
                'gundam': (1024, 640, True),
            }
            base_size, image_size, crop_mode = mode_configs.get(mode, (1024, 1024, False))
            
            prompt = "<image>\n<|grounding|>Convert the document to markdown."
            
            # Perform OCR
            with tempfile.TemporaryDirectory() as output_dir:
                result = self.model.infer(
                    self.tokenizer,
                    prompt=prompt,
                    image_file=image_file,
                    output_path=output_dir,
                    base_size=base_size,
                    image_size=image_size,
                    crop_mode=crop_mode,
                    save_results=False,
                    test_compress=False
                )
            
            # Cleanup
            os.unlink(image_file)
            
            return {
                'success': True,
                'text': result,
                'mode': mode,
                'device': 'cuda'
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }

# Web endpoint
@app.function()
@modal.web_endpoint(method="POST")
def ocr(data: dict):
    """
    HTTP endpoint for OCR processing
    
    POST with JSON body:
    {
        "image": "base64_encoded_image",
        "mode": "base"  // optional: tiny, small, base, large, gundam
    }
    """
    if 'image' not in data:
        return {'success': False, 'error': 'No image provided'}
    
    model = DeepSeekOCRModel()
    result = model.process_receipt.remote(
        data['image'],
        data.get('mode', 'base')
    )
    
    return result

@app.function()
@modal.web_endpoint(method="GET")
def health():
    """Health check endpoint"""
    return {
        'status': 'ok',
        'service': 'DeepSeek-OCR (Modal Serverless)',
        'version': '1.0.0',
        'model': MODEL_NAME,
        'modes': ['tiny', 'small', 'base', 'large', 'gundam']
    }

# Local testing
@app.local_entrypoint()
def main():
    """Test the deployment locally"""
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: modal run modal_deepseek_deploy.py <image_path>")
        return
    
    image_path = sys.argv[1]
    
    # Read and encode image
    with open(image_path, 'rb') as f:
        image_data = f.read()
        image_b64 = base64.b64encode(image_data).decode()
    
    # Process
    print(f"Processing {image_path}...")
    model = DeepSeekOCRModel()
    result = model.process_receipt.remote(image_b64, "base")
    
    if result['success']:
        print("\n✅ SUCCESS!")
        print(f"Mode: {result['mode']}")
        print(f"Text length: {len(result['text'])} chars")
        print("\nExtracted text:")
        print("-" * 60)
        print(result['text'])
        print("-" * 60)
    else:
        print(f"\n❌ ERROR: {result['error']}")




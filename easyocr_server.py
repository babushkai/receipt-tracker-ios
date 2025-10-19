#!/usr/bin/env python3
"""
EasyOCR Server for ReceiptTracker
Provides a REST API endpoint for OCR using EasyOCR
"""

from flask import Flask, request, jsonify
import easyocr
import base64
import numpy as np
from PIL import Image
import io
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Initialize EasyOCR readers
# Create readers for different language combinations
logging.info("🔧 Initializing EasyOCR readers...")
reader_en = easyocr.Reader(['en'], gpu=False)
reader_jp = easyocr.Reader(['ja'], gpu=False)
reader_multi = easyocr.Reader(['en', 'ja'], gpu=False)
logging.info("✅ EasyOCR readers initialized!")

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'service': 'EasyOCR Server',
        'version': '1.0.0',
        'languages': ['en', 'ja', 'multi']
    })

@app.route('/ocr', methods=['POST'])
def perform_ocr():
    """
    Perform OCR on uploaded image
    
    Request body:
    {
        "image": "base64_encoded_image_data",
        "lang": "en" | "ja" | "multi"  (optional, defaults to "multi")
    }
    
    Response:
    {
        "success": true,
        "text": "extracted text",
        "lines": [...],
        "confidence": 0.95
    }
    """
    try:
        data = request.get_json()
        
        if 'image' not in data:
            return jsonify({
                'success': False,
                'error': 'No image data provided'
            }), 400
        
        # Decode base64 image
        image_data = base64.b64decode(data['image'])
        image = Image.open(io.BytesIO(image_data))
        image_np = np.array(image)
        
        # Get language preference
        lang = data.get('lang', 'multi')
        
        # Select appropriate reader
        logging.info(f"Processing image with language: {lang}")
        
        if lang == 'en':
            reader = reader_en
        elif lang == 'ja':
            reader = reader_jp
        else:
            reader = reader_multi
        
        # Perform OCR
        result = reader.readtext(image_np)
        
        if not result:
            return jsonify({
                'success': False,
                'error': 'No text detected in image'
            }), 200
        
        # Extract text and confidence scores
        extracted_lines = []
        confidences = []
        
        for detection in result:
            bbox = detection[0]  # Bounding box coordinates
            text = detection[1]  # Text
            confidence = detection[2]  # Confidence score
            
            extracted_lines.append(text)
            confidences.append(confidence)
        
        # Combine all text with newlines
        full_text = '\n'.join(extracted_lines)
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0
        
        logging.info(f"Extracted {len(extracted_lines)} lines with avg confidence {avg_confidence:.2f}")
        
        return jsonify({
            'success': True,
            'text': full_text,
            'lines': extracted_lines,
            'confidence': avg_confidence,
            'language': lang,
            'line_count': len(extracted_lines)
        })
        
    except Exception as e:
        logging.error(f"OCR error: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/ocr/batch', methods=['POST'])
def perform_batch_ocr():
    """
    Perform OCR on multiple images
    
    Request body:
    {
        "images": ["base64_1", "base64_2", ...],
        "lang": "en" | "ja" | "multi"
    }
    """
    try:
        data = request.get_json()
        images = data.get('images', [])
        lang = data.get('lang', 'multi')
        
        # Select appropriate reader
        if lang == 'en':
            reader = reader_en
        elif lang == 'ja':
            reader = reader_jp
        else:
            reader = reader_multi
        
        results = []
        for idx, image_b64 in enumerate(images):
            logging.info(f"Processing image {idx + 1}/{len(images)}")
            
            image_data = base64.b64decode(image_b64)
            image = Image.open(io.BytesIO(image_data))
            image_np = np.array(image)
            
            result = reader.readtext(image_np)
            
            if result:
                extracted_lines = [detection[1] for detection in result]
                confidences = [detection[2] for detection in result]
                avg_confidence = sum(confidences) / len(confidences) if confidences else 0
                
                results.append({
                    'success': True,
                    'text': '\n'.join(extracted_lines),
                    'confidence': avg_confidence
                })
            else:
                results.append({
                    'success': False,
                    'error': 'No text detected'
                })
        
        return jsonify({
            'success': True,
            'results': results,
            'total': len(images),
            'successful': sum(1 for r in results if r['success'])
        })
        
    except Exception as e:
        logging.error(f"Batch OCR error: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    print("=" * 60)
    print("🚀 Starting EasyOCR Server")
    print("=" * 60)
    print("📍 Server will run on: http://localhost:5001")
    print("🔍 Endpoints:")
    print("   - GET  /health       → Health check")
    print("   - POST /ocr          → Single image OCR")
    print("   - POST /ocr/batch    → Batch image OCR")
    print("")
    print("🌐 Supported languages:")
    print("   - 'en'    → English only")
    print("   - 'ja'    → Japanese only")
    print("   - 'multi' → English + Japanese (default)")
    print("")
    print("💡 EasyOCR supports 80+ languages!")
    print("💡 Note: Using port 5001 (5000 is used by macOS AirPlay)")
    print("=" * 60)
    
    app.run(host='0.0.0.0', port=5001, debug=False)


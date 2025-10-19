#!/usr/bin/env python3
"""
PaddleOCR Server for ReceiptTracker
Provides a REST API endpoint for OCR using PaddleOCR
"""

from flask import Flask, request, jsonify
from paddleocr import PaddleOCR
import base64
import numpy as np
from PIL import Image
import io
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Initialize PaddleOCR
# use_angle_cls=True enables rotation detection
# lang='en' for English, use 'japan' for Japanese, 'ch' for Chinese
ocr = PaddleOCR(
    use_angle_cls=True,
    lang='en',  # Change to 'japan' or 'ch' as needed
    use_gpu=False,  # Set to True if you have CUDA GPU
    show_log=False
)

# Also initialize Japanese OCR
ocr_jp = PaddleOCR(
    use_angle_cls=True,
    lang='japan',
    use_gpu=False,
    show_log=False
)

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'service': 'PaddleOCR Server',
        'version': '1.0.0',
        'languages': ['en', 'japan']
    })

@app.route('/ocr', methods=['POST'])
def perform_ocr():
    """
    Perform OCR on uploaded image
    
    Request body:
    {
        "image": "base64_encoded_image_data",
        "lang": "en" | "japan" | "auto"  (optional, defaults to "auto")
    }
    
    Response:
    {
        "success": true,
        "text": "extracted text",
        "boxes": [...],  // bounding boxes
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
        lang = data.get('lang', 'auto')
        
        # Perform OCR
        logging.info(f"Processing image with language: {lang}")
        
        if lang == 'japan':
            result = ocr_jp.ocr(image_np, cls=True)
        elif lang == 'auto':
            # Try both and use the one with higher confidence
            result_en = ocr.ocr(image_np, cls=True)
            result_jp = ocr_jp.ocr(image_np, cls=True)
            
            # Calculate average confidence for each
            conf_en = calculate_confidence(result_en)
            conf_jp = calculate_confidence(result_jp)
            
            if conf_jp > conf_en:
                result = result_jp
                detected_lang = 'japan'
                logging.info(f"Auto-detected Japanese (confidence: {conf_jp:.2f} vs {conf_en:.2f})")
            else:
                result = result_en
                detected_lang = 'en'
                logging.info(f"Auto-detected English (confidence: {conf_en:.2f} vs {conf_jp:.2f})")
        else:
            result = ocr.ocr(image_np, cls=True)
            detected_lang = 'en'
        
        if not result or not result[0]:
            return jsonify({
                'success': False,
                'error': 'No text detected in image'
            }), 200
        
        # Extract text and boxes
        extracted_lines = []
        boxes = []
        confidences = []
        
        for line in result[0]:
            box = line[0]
            text = line[1][0]
            confidence = line[1][1]
            
            extracted_lines.append(text)
            boxes.append(box)
            confidences.append(confidence)
        
        # Combine all text
        full_text = '\n'.join(extracted_lines)
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0
        
        logging.info(f"Extracted {len(extracted_lines)} lines with avg confidence {avg_confidence:.2f}")
        
        return jsonify({
            'success': True,
            'text': full_text,
            'lines': extracted_lines,
            'boxes': boxes,
            'confidence': avg_confidence,
            'language': detected_lang if lang == 'auto' else lang,
            'line_count': len(extracted_lines)
        })
        
    except Exception as e:
        logging.error(f"OCR error: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

def calculate_confidence(result):
    """Calculate average confidence from OCR result"""
    if not result or not result[0]:
        return 0.0
    
    confidences = [line[1][1] for line in result[0]]
    return sum(confidences) / len(confidences) if confidences else 0.0

@app.route('/ocr/batch', methods=['POST'])
def perform_batch_ocr():
    """
    Perform OCR on multiple images
    
    Request body:
    {
        "images": ["base64_1", "base64_2", ...],
        "lang": "en" | "japan" | "auto"
    }
    """
    try:
        data = request.get_json()
        images = data.get('images', [])
        lang = data.get('lang', 'auto')
        
        results = []
        for idx, image_b64 in enumerate(images):
            logging.info(f"Processing image {idx + 1}/{len(images)}")
            
            image_data = base64.b64decode(image_b64)
            image = Image.open(io.BytesIO(image_data))
            image_np = np.array(image)
            
            if lang == 'japan':
                result = ocr_jp.ocr(image_np, cls=True)
            else:
                result = ocr.ocr(image_np, cls=True)
            
            if result and result[0]:
                extracted_lines = [line[1][0] for line in result[0]]
                confidences = [line[1][1] for line in result[0]]
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
    print("🚀 Starting PaddleOCR Server")
    print("=" * 60)
    print("📍 Server will run on: http://localhost:5000")
    print("🔍 Endpoints:")
    print("   - GET  /health       → Health check")
    print("   - POST /ocr          → Single image OCR")
    print("   - POST /ocr/batch    → Batch image OCR")
    print("")
    print("🌐 Supported languages: English, Japanese (auto-detect)")
    print("=" * 60)
    
    app.run(host='0.0.0.0', port=5000, debug=False)


#!/usr/bin/env python3
"""
Secure OCR Gateway API - Proxy for iOS App
This acts as a secure gateway between your iOS app and the DeepSeek OCR server

Features:
- Authentication with API keys
- Rate limiting
- Input validation
- Request logging
- Error handling
- CORS support for web clients (optional)

Deploy this on your backend server, NOT the OCR server itself!
"""

from flask import Flask, request, jsonify
from functools import wraps
import requests
import hashlib
import time
import logging
from datetime import datetime, timedelta
import os

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/workspace/deepseek-build/ocr_gateway.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ========== CONFIGURATION ==========
# !!! CHANGE THESE IN PRODUCTION !!!
API_KEYS = {
    # Format: "api_key": {"user": "username", "tier": "free|pro", "daily_limit": 100}
    "ios_app_key_123xyz": {"user": "ios_app", "tier": "pro", "daily_limit": 1000},
    "test_key_456abc": {"user": "test_user", "tier": "free", "daily_limit": 50},
}

# Internal OCR server (NOT exposed to internet)
OCR_SERVER_URL = "http://localhost:5003"

# Rate limiting storage (use Redis in production!)
rate_limit_storage = {}

# ========== AUTHENTICATION ==========
def require_api_key(f):
    """Decorator to require API key authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        api_key = request.headers.get('X-API-Key')
        
        if not api_key:
            logger.warning(f"Missing API key from {request.remote_addr}")
            return jsonify({
                'success': False,
                'error': 'Missing API key. Include X-API-Key header.'
            }), 401
        
        if api_key not in API_KEYS:
            logger.warning(f"Invalid API key attempt from {request.remote_addr}")
            return jsonify({
                'success': False,
                'error': 'Invalid API key'
            }), 403
        
        # Add user info to request
        request.api_user = API_KEYS[api_key]
        request.api_key = api_key
        
        return f(*args, **kwargs)
    
    return decorated_function

# ========== RATE LIMITING ==========
def check_rate_limit(api_key, limit=100, window=86400):
    """
    Check if user has exceeded rate limit
    limit: number of requests allowed
    window: time window in seconds (default 24 hours)
    """
    now = time.time()
    user_data = API_KEYS.get(api_key, {})
    daily_limit = user_data.get('daily_limit', 50)
    
    if api_key not in rate_limit_storage:
        rate_limit_storage[api_key] = []
    
    # Remove old requests outside the window
    rate_limit_storage[api_key] = [
        req_time for req_time in rate_limit_storage[api_key]
        if now - req_time < window
    ]
    
    # Check if limit exceeded
    if len(rate_limit_storage[api_key]) >= daily_limit:
        return False, len(rate_limit_storage[api_key]), daily_limit
    
    # Record this request
    rate_limit_storage[api_key].append(now)
    
    return True, len(rate_limit_storage[api_key]), daily_limit

# ========== VALIDATION ==========
def validate_ocr_request(data):
    """Validate incoming OCR request"""
    if not data:
        return False, "No JSON data provided"
    
    if 'image' not in data:
        return False, "Missing 'image' field"
    
    image = data['image']
    
    # Check if it's a URL or base64
    if isinstance(image, str):
        if image.startswith('http://') or image.startswith('https://'):
            # URL validation
            if len(image) > 2048:
                return False, "Image URL too long"
        else:
            # Base64 validation
            if len(image) > 15 * 1024 * 1024:  # 15MB base64 limit
                return False, "Image data too large"
    else:
        return False, "Invalid image format"
    
    return True, None

def validate_batch_request(data):
    """Validate batch OCR request"""
    if not data:
        return False, "No JSON data provided"
    
    if 'images' not in data:
        return False, "Missing 'images' field"
    
    images = data['images']
    
    if not isinstance(images, list):
        return False, "'images' must be an array"
    
    if len(images) == 0:
        return False, "Empty images array"
    
    if len(images) > 10:  # Limit batch size
        return False, "Maximum 10 images per batch"
    
    return True, None

# ========== API ENDPOINTS ==========

@app.route('/health', methods=['GET'])
def health():
    """Public health check endpoint"""
    try:
        # Check if OCR server is reachable
        response = requests.get(f"{OCR_SERVER_URL}/health", timeout=5)
        ocr_status = response.json() if response.status_code == 200 else {"status": "error"}
    except Exception as e:
        ocr_status = {"status": "error", "message": str(e)}
    
    return jsonify({
        'status': 'ok',
        'service': 'OCR Gateway API',
        'version': '1.0.0',
        'ocr_backend': ocr_status.get('status', 'unknown')
    })

@app.route('/api/v1/ocr', methods=['POST'])
@require_api_key
def proxy_ocr():
    """
    Proxy single image OCR request to internal server
    
    Headers:
        X-API-Key: Your API key
    
    Body (JSON):
        {
            "image": "https://example.com/image.jpg" or "base64_string",
            "prompt": "Extract all text." (optional)
        }
    
    Response:
        {
            "success": true,
            "text": "extracted text...",
            "usage": {
                "requests_used": 5,
                "daily_limit": 100
            }
        }
    """
    # Rate limiting
    allowed, used, limit = check_rate_limit(request.api_key)
    if not allowed:
        logger.warning(f"Rate limit exceeded for {request.api_user['user']}")
        return jsonify({
            'success': False,
            'error': 'Rate limit exceeded',
            'usage': {
                'requests_used': used,
                'daily_limit': limit
            }
        }), 429
    
    # Validate request
    data = request.get_json()
    valid, error = validate_ocr_request(data)
    if not valid:
        logger.warning(f"Invalid request from {request.api_user['user']}: {error}")
        return jsonify({
            'success': False,
            'error': error
        }), 400
    
    # Log request
    logger.info(f"OCR request from {request.api_user['user']} (tier: {request.api_user['tier']})")
    
    try:
        # Forward to internal OCR server
        response = requests.post(
            f"{OCR_SERVER_URL}/ocr",
            json=data,
            timeout=120
        )
        
        result = response.json()
        
        # Add usage information
        if result.get('success'):
            result['usage'] = {
                'requests_used': used,
                'daily_limit': limit,
                'tier': request.api_user['tier']
            }
        
        logger.info(f"OCR completed for {request.api_user['user']}: success={result.get('success')}")
        
        return jsonify(result), response.status_code
        
    except requests.Timeout:
        logger.error(f"OCR timeout for {request.api_user['user']}")
        return jsonify({
            'success': False,
            'error': 'OCR request timed out'
        }), 504
    except Exception as e:
        logger.error(f"OCR error for {request.api_user['user']}: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

@app.route('/api/v1/ocr/batch', methods=['POST'])
@require_api_key
def proxy_batch_ocr():
    """
    Proxy batch OCR request to internal server
    
    Headers:
        X-API-Key: Your API key
    
    Body (JSON):
        {
            "images": ["url1", "url2", ...],
            "prompt": "Extract all text." (optional)
        }
    
    Response:
        {
            "success": true,
            "results": [...],
            "total": 3,
            "successful": 3,
            "usage": {...}
        }
    """
    # Rate limiting (batch requests count as multiple requests)
    data = request.get_json()
    valid, error = validate_batch_request(data)
    if not valid:
        return jsonify({
            'success': False,
            'error': error
        }), 400
    
    num_images = len(data['images'])
    
    # Check if user has enough quota for batch
    allowed, used, limit = check_rate_limit(request.api_key)
    if used + num_images > limit:
        logger.warning(f"Insufficient quota for {request.api_user['user']}")
        return jsonify({
            'success': False,
            'error': f'Insufficient quota. Batch requires {num_images} requests, but only {limit - used} remaining.',
            'usage': {
                'requests_used': used,
                'daily_limit': limit
            }
        }), 429
    
    # Record batch requests
    for _ in range(num_images):
        rate_limit_storage[request.api_key].append(time.time())
    
    logger.info(f"Batch OCR request from {request.api_user['user']}: {num_images} images")
    
    try:
        # Forward to internal OCR server
        response = requests.post(
            f"{OCR_SERVER_URL}/ocr/batch",
            json=data,
            timeout=300  # 5 minutes for batch
        )
        
        result = response.json()
        
        # Add usage information
        if result.get('success'):
            result['usage'] = {
                'requests_used': used + num_images,
                'daily_limit': limit,
                'tier': request.api_user['tier']
            }
        
        logger.info(f"Batch OCR completed for {request.api_user['user']}: {result.get('successful', 0)}/{num_images} successful")
        
        return jsonify(result), response.status_code
        
    except requests.Timeout:
        logger.error(f"Batch OCR timeout for {request.api_user['user']}")
        return jsonify({
            'success': False,
            'error': 'Batch OCR request timed out'
        }), 504
    except Exception as e:
        logger.error(f"Batch OCR error for {request.api_user['user']}: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Internal server error'
        }), 500

@app.route('/api/v1/usage', methods=['GET'])
@require_api_key
def get_usage():
    """Get current usage statistics for the authenticated user"""
    api_key = request.api_key
    user_info = request.api_user
    
    used = len([
        req_time for req_time in rate_limit_storage.get(api_key, [])
        if time.time() - req_time < 86400
    ])
    
    return jsonify({
        'success': True,
        'usage': {
            'user': user_info['user'],
            'tier': user_info['tier'],
            'requests_used': used,
            'daily_limit': user_info['daily_limit'],
            'requests_remaining': user_info['daily_limit'] - used
        }
    })

# ========== ERROR HANDLERS ==========

@app.errorhandler(413)
def request_entity_too_large(error):
    return jsonify({
        'success': False,
        'error': 'Request too large. Maximum 16MB.'
    }), 413

@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'success': False,
        'error': 'Endpoint not found'
    }), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal error: {str(error)}")
    return jsonify({
        'success': False,
        'error': 'Internal server error'
    }), 500

if __name__ == '__main__':
    print("=" * 70)
    print("🔐 Starting Secure OCR Gateway API")
    print("=" * 70)
    print()
    print("⚠️  SECURITY NOTES:")
    print("   1. Change API_KEYS in production!")
    print("   2. Use environment variables for secrets")
    print("   3. Deploy behind NGINX/Apache with SSL")
    print("   4. Use Redis for rate limiting in production")
    print("   5. Enable firewall rules to restrict OCR server access")
    print()
    print("📍 Gateway running on: http://localhost:8000")
    print("🔒 OCR Server (internal): http://localhost:5003")
    print()
    print("📚 API Endpoints:")
    print("   - GET  /health              → Health check")
    print("   - POST /api/v1/ocr          → Single image OCR")
    print("   - POST /api/v1/ocr/batch    → Batch OCR")
    print("   - GET  /api/v1/usage        → Usage statistics")
    print()
    print("🔑 Test API Key: ios_app_key_123xyz")
    print("=" * 70)
    
    # Run on different port than OCR server
    app.run(host='0.0.0.0', port=8000, debug=False)


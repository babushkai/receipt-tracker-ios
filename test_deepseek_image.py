#!/usr/bin/env python3
"""
Test DeepSeek-OCR server with a sample receipt image
"""

import base64
import json
import requests
from pathlib import Path

# Server URL (change this to your RunPod URL if deployed)
SERVER_URL = "http://localhost:5003"

def test_health():
    """Test server health endpoint"""
    print("🔍 Checking server health...")
    try:
        response = requests.get(f"{SERVER_URL}/health", timeout=5)
        print(f"✅ Server is running!")
        print(json.dumps(response.json(), indent=2))
        return True
    except Exception as e:
        print(f"❌ Server not reachable: {e}")
        return False

def test_ocr(image_path: str, prompt: str = "Free OCR."):
    """Test OCR with an image"""
    print(f"\n📸 Testing OCR with image: {image_path}")
    print(f"📝 Prompt: {prompt}")
    
    # Read and encode image
    try:
        with open(image_path, 'rb') as f:
            image_data = base64.b64encode(f.read()).decode('utf-8')
    except Exception as e:
        print(f"❌ Failed to read image: {e}")
        return
    
    # Send request
    try:
        print("⏳ Sending request to server...")
        response = requests.post(
            f"{SERVER_URL}/ocr",
            json={
                "image": image_data,
                "prompt": prompt
            },
            timeout=60  # OCR can take a while
        )
        
        result = response.json()
        
        if result.get('success'):
            print("✅ OCR successful!")
            print(f"📄 Extracted text ({len(result['text'])} characters):")
            print("=" * 70)
            print(result['text'])
            print("=" * 70)
        else:
            print(f"❌ OCR failed: {result.get('error')}")
            
    except Exception as e:
        print(f"❌ Request failed: {e}")

def test_batch_ocr(image_paths: list, prompt: str = "Free OCR."):
    """Test batch OCR with multiple images"""
    print(f"\n📸 Testing batch OCR with {len(image_paths)} images")
    
    # Read and encode all images
    images = []
    for path in image_paths:
        try:
            with open(path, 'rb') as f:
                image_data = base64.b64encode(f.read()).decode('utf-8')
                images.append(image_data)
                print(f"✅ Loaded: {path}")
        except Exception as e:
            print(f"❌ Failed to read {path}: {e}")
            return
    
    # Send batch request
    try:
        print("⏳ Sending batch request to server...")
        response = requests.post(
            f"{SERVER_URL}/ocr/batch",
            json={
                "images": images,
                "prompt": prompt
            },
            timeout=120  # Batch can take longer
        )
        
        result = response.json()
        
        if result.get('success'):
            print(f"✅ Batch OCR successful! {result['successful']}/{result['total']} images processed")
            
            for idx, res in enumerate(result['results']):
                print(f"\n📄 Image {idx + 1} ({res['length']} characters):")
                print("=" * 70)
                print(res['text'][:500])  # Show first 500 chars
                if len(res['text']) > 500:
                    print(f"... (truncated, {len(res['text']) - 500} more chars)")
                print("=" * 70)
        else:
            print(f"❌ Batch OCR failed: {result.get('error')}")
            
    except Exception as e:
        print(f"❌ Request failed: {e}")

if __name__ == "__main__":
    print("🚀 DeepSeek-OCR Server Test (vLLM)")
    print("=" * 70)
    
    # Test health
    if not test_health():
        print("\n💡 Make sure the server is running:")
        print("   ./start_deepseek.sh")
        exit(1)
    
    # Check for sample receipts
    sample_dir = Path("Assets.xcassets/SampleReceipts.dataset")
    if sample_dir.exists():
        samples = list(sample_dir.glob("*.txt"))
        print(f"\n📁 Found {len(samples)} sample receipt text files")
        print("💡 These are text files, not images. Use your own receipt images for testing.")
    
    # Test with a custom image if provided
    print("\n" + "=" * 70)
    print("💡 Usage examples:")
    print("   python3 test_deepseek_image.py")
    print("\n📝 To test with your own image:")
    print("   1. Save a receipt image as 'test_receipt.jpg'")
    print("   2. Run: python3 -c \"from test_deepseek_image import test_ocr; test_ocr('test_receipt.jpg')\"")
    print("\n📝 To test batch processing:")
    print("   from test_deepseek_image import test_batch_ocr")
    print("   test_batch_ocr(['receipt1.jpg', 'receipt2.jpg'])")
    print("\n🔗 For RunPod deployment, update SERVER_URL in this script")
    print("=" * 70)



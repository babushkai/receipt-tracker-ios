#!/usr/bin/env python3
"""
Test batch OCR with real text images from the internet
"""
import requests
import json
import time

# Collection of real text document images from Wikimedia Commons
test_images = [
    # 1. Receipt image
    "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0b/ReceiptSwiss.jpg/800px-ReceiptSwiss.jpg",
    
    # 2. Book page with text
    "https://upload.wikimedia.org/wikipedia/commons/thumb/7/72/Gutenberg_Bible_B42_1a.jpg/600px-Gutenberg_Bible_B42_1a.jpg",
    
    # 3. Newspaper clipping
    "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Albert_Einstein_in_the_New_York_Times_1935.jpg/600px-Albert_Einstein_in_the_New_York_Times_1935.jpg",
    
    # 4. Handwritten note
    "https://upload.wikimedia.org/wikipedia/commons/thumb/3/39/Abraham_Lincoln_O-77_matte_collodion_print.jpg/400px-Abraham_Lincoln_O-77_matte_collodion_print.jpg"
]

print("🚀 Testing Batch OCR with Text Document Images")
print("=" * 70)
print(f"📸 Processing {len(test_images)} images...")
print()

# Prepare the batch request
payload = {
    "images": test_images,
    "prompt": "Extract all visible text from this document or image. Preserve structure and formatting."
}

# Send batch OCR request
ocr_url = "http://localhost:5003/ocr/batch"
start_time = time.time()

print(f"⏳ Sending batch request to {ocr_url}...")
try:
    response = requests.post(ocr_url, json=payload, timeout=300)
    elapsed = time.time() - start_time
    
    result = response.json()
    
    if result.get('success'):
        print(f"✅ Batch OCR completed in {elapsed:.1f} seconds!")
        print()
        print("=" * 70)
        print("📊 RESULTS")
        print("=" * 70)
        
        results = result.get('results', [])
        total = result.get('total', 0)
        successful = result.get('successful', 0)
        
        print(f"Total images: {total}")
        print(f"Successful: {successful}")
        print(f"Engine: {result.get('engine', 'N/A')}")
        print()
        
        for idx, res in enumerate(results, 1):
            print(f"\n--- Image {idx} ---")
            if res.get('success'):
                text = res.get('text', '')
                length = res.get('length', 0)
                print(f"Status: ✅ Success")
                print(f"Length: {length} characters")
                print(f"Preview (first 300 chars):")
                print(f"  {text[:300]}")
                if len(text) > 300:
                    print("  ...")
            else:
                print(f"Status: ❌ Failed")
                print(f"Error: {res.get('error', 'Unknown')}")
        
        # Save results
        output_file = "/workspace/deepseek-build/batch_ocr_results.json"
        with open(output_file, 'w') as f:
            json.dump(result, f, indent=2)
        print(f"\n💾 Full results saved to: {output_file}")
        
    else:
        print(f"❌ Batch OCR failed: {result.get('error')}")
        
except requests.Timeout:
    print("⏰ Request timed out after 5 minutes")
except Exception as e:
    print(f"❌ Error: {str(e)}")


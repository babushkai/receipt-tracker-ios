#!/usr/bin/env python3
"""
Test script to OCR the "Attention Is All You Need" paper
Downloads PDF, converts pages to images, and sends to DeepSeek OCR server
"""
import requests
import base64
import io
from pdf2image import convert_from_path
from PIL import Image
import json

# Download the paper
print("📥 Downloading 'Attention Is All You Need' paper...")
pdf_url = "https://arxiv.org/pdf/1706.03762"
response = requests.get(pdf_url)
pdf_path = "/tmp/attention_is_all_you_need.pdf"

with open(pdf_path, 'wb') as f:
    f.write(response.content)
print(f"✅ Downloaded PDF ({len(response.content)} bytes)")

# Convert first 3 pages to images (to save time)
print("\n🖼️  Converting PDF pages to images...")
images = convert_from_path(pdf_path, first_page=1, last_page=3, dpi=150)
print(f"✅ Converted {len(images)} pages to images")

# Process each page with OCR
ocr_url = "http://localhost:5003/ocr"
results = []

for idx, img in enumerate(images, 1):
    print(f"\n📄 Processing page {idx}...")
    
    # Convert PIL image to base64
    buffer = io.BytesIO()
    img.save(buffer, format='PNG')
    img_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')
    
    # Send to OCR server
    payload = {
        "image": img_base64,
        "prompt": "Extract all text from this academic paper page. Preserve structure, headings, and formatting."
    }
    
    try:
        response = requests.post(ocr_url, json=payload, timeout=120)
        result = response.json()
        
        if result.get('success'):
            text = result.get('text', '')
            print(f"✅ Extracted {len(text)} characters from page {idx}")
            print(f"\n--- Page {idx} Preview (first 500 chars) ---")
            print(text[:500])
            print("...\n")
            results.append({
                'page': idx,
                'text': text,
                'length': len(text)
            })
        else:
            print(f"❌ OCR failed for page {idx}: {result.get('error')}")
            results.append({
                'page': idx,
                'error': result.get('error')
            })
    except Exception as e:
        print(f"❌ Error processing page {idx}: {str(e)}")
        results.append({
            'page': idx,
            'error': str(e)
        })

# Summary
print("\n" + "="*70)
print("📊 OCR SUMMARY")
print("="*70)
successful = sum(1 for r in results if 'text' in r)
print(f"✅ Successfully processed: {successful}/{len(images)} pages")
total_chars = sum(r.get('length', 0) for r in results if 'text' in r)
print(f"📝 Total characters extracted: {total_chars:,}")

# Save full results to file
output_file = "/workspace/deepseek-build/transformer_paper_ocr.json"
with open(output_file, 'w') as f:
    json.dump(results, f, indent=2)
print(f"\n💾 Full results saved to: {output_file}")


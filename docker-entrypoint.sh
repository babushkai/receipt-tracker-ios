#!/bin/bash
# Docker entrypoint script for Receipt Tracker OCR Backend
# Supports running OCR server, gateway, or both

set -e

MODE="${1:-both}"

echo "=========================================="
echo "Receipt Tracker OCR Backend"
echo "=========================================="
echo "Mode: $MODE"
echo ""

case "$MODE" in
  ocr-only)
    echo "🚀 Starting OCR Server only (port 5003)..."
    exec python3 deepseek_ocr_server.py
    ;;
  
  gateway-only)
    echo "🔐 Starting Gateway API only (port 8000)..."
    exec python3 secure_ocr_gateway.py
    ;;
  
  both)
    echo "🚀 Starting both OCR Server (5003) and Gateway API (8000)..."
    
    # Start OCR server in background
    echo "Starting OCR server..."
    python3 deepseek_ocr_server.py &
    OCR_PID=$!
    
    # Wait for OCR server to be ready
    echo "Waiting for OCR server to initialize..."
    for i in {1..60}; do
      if curl -s http://localhost:5003/health > /dev/null 2>&1; then
        echo "✅ OCR server is ready!"
        break
      fi
      if [ $i -eq 60 ]; then
        echo "❌ OCR server failed to start"
        exit 1
      fi
      sleep 2
    done
    
    # Start gateway in foreground
    echo "Starting Gateway API..."
    exec python3 secure_ocr_gateway.py
    ;;
  
  *)
    echo "❌ Invalid mode: $MODE"
    echo "Valid modes: ocr-only, gateway-only, both"
    exit 1
    ;;
esac


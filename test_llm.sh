#!/bin/bash

# Test script to verify Anthropic API key works
# Usage: ./test_llm.sh YOUR_API_KEY

API_KEY="$1"

if [ -z "$API_KEY" ]; then
    echo "Usage: ./test_llm.sh YOUR_API_KEY"
    exit 1
fi

echo "🧪 Testing Anthropic API..."
echo ""

curl -s -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 100,
    "messages": [
      {
        "role": "user",
        "content": "Say hello"
      }
    ]
  }' | python3 -m json.tool

echo ""
echo "✅ If you see a response above, your API key works!"
echo "❌ If you see an error, your API key is invalid or expired."


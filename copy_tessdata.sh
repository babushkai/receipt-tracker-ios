#!/bin/bash
# Copy tessdata files to app bundle for Tesseract OCR

set -e

echo "📦 Copying tessdata files..."

# Source and destination
TESSDATA_DIR="${SRCROOT}/tessdata"
DEST_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/tessdata"

# Create destination directory if needed
mkdir -p "${DEST_DIR}"

# Copy tessdata files
if [ -d "${TESSDATA_DIR}" ]; then
    cp -R "${TESSDATA_DIR}/"* "${DEST_DIR}/"
    echo "✅ Tessdata files copied successfully"
else
    echo "⚠️  Warning: tessdata directory not found at ${TESSDATA_DIR}"
    echo "   Tesseract OCR may not work properly"
fi


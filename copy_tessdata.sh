#!/bin/bash
# Script to copy tessdata to app bundle

set -e

echo "📦 Copying tessdata to app bundle..."

# Source and destination
SOURCE_DIR="${SRCROOT}/tessdata"
DEST_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/tessdata"

# Create destination directory
mkdir -p "${DEST_DIR}"

# Copy tessdata folder contents
if [ -d "${SOURCE_DIR}" ]; then
    echo "✅ Found source: ${SOURCE_DIR}"
    cp -R "${SOURCE_DIR}/"* "${DEST_DIR}/"
    echo "✅ Copied tessdata to: ${DEST_DIR}"
    
    # Verify eng.traineddata exists
    if [ -f "${DEST_DIR}/eng.traineddata" ]; then
        echo "✅ Verified: eng.traineddata is in bundle"
    else
        echo "❌ ERROR: eng.traineddata not found!"
        exit 1
    fi
else
    echo "❌ ERROR: Source directory not found: ${SOURCE_DIR}"
    exit 1
fi

echo "✅ tessdata copy complete!"


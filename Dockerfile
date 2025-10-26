# Multi-stage Dockerfile for Receipt Tracker OCR Backend
# Optimized for GitHub Container Registry
# Includes both OCR Server and Secure Gateway

FROM nvidia/cuda:12.1.0-devel-ubuntu22.04 AS ocr-server

# Metadata
LABEL org.opencontainers.image.source="https://github.com/babushkai/receipt-tracker-ios"
LABEL org.opencontainers.image.description="DeepSeek OCR Server for Receipt Tracker iOS App"
LABEL org.opencontainers.image.licenses="MIT"

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"
ENV HF_HUB_ENABLE_HF_TRANSFER=0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3-dev \
    git \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    flask>=3.0.0 \
    pillow>=10.0.0 \
    requests>=2.31.0 \
    gunicorn>=21.0.0

# Install vLLM (optimized for DeepSeek-OCR)
RUN pip3 install --no-cache-dir vllm --pre --extra-index-url https://wheels.vllm.ai/nightly

# Set working directory
WORKDIR /app

# Copy server files
COPY deepseek_ocr_server.py /app/
COPY secure_ocr_gateway.py /app/

# Create model cache directory
RUN mkdir -p /app/model_cache

# Expose ports
# 5003 - OCR Server (internal)
# 8000 - Gateway API (public)
EXPOSE 5003 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:5003/health && curl -f http://localhost:8000/health || exit 1

# Copy startup script
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

# Default: Run both OCR server and gateway
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["both"]

# Alternative commands:
# docker run <image> ocr-only    # Run only OCR server
# docker run <image> gateway-only # Run only gateway
# docker run <image> both         # Run both (default)


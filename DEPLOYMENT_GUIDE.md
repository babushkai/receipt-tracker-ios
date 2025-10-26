# 🚀 Secure OCR API Deployment Guide

## Architecture Overview

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   iOS App   │ ◄─────► │  Gateway API     │ ◄─────► │  OCR Server     │
│  (Public)   │  HTTPS  │  (Your Backend)  │  Local  │  (Private)      │
│             │  🔐     │  Port: 443/8000  │  Only   │  Port: 5003     │
└─────────────┘         └──────────────────┘         └─────────────────┘
                         - Authentication              - Not exposed
                         - Rate limiting               - GPU-accelerated
                         - Input validation            - vLLM powered
```

## 🔒 Security Architecture

### What's Public:
- ✅ Gateway API (port 8000 → 443 with SSL)
- ✅ Health check endpoint
- ✅ API documentation

### What's Private (Internal Only):
- 🔐 OCR Server (port 5003)
- 🔐 Database credentials
- 🔐 API keys
- 🔐 Internal network

## 📋 Prerequisites

1. **Server Requirements:**
   - Linux server with GPU (NVIDIA recommended)
   - At least 16GB RAM
   - 50GB disk space
   - CUDA 12.x installed

2. **Network Setup:**
   - Domain name (e.g., api.yourcompany.com)
   - SSL certificate (Let's Encrypt)
   - Firewall configured

## 🛠️ Step-by-Step Deployment

### Step 1: Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y python3-pip nginx certbot python3-certbot-nginx

# Install Python packages
pip3 install flask requests gunicorn
```

### Step 2: Deploy OCR Server (Internal Only)

```bash
# Copy OCR server files
cd /opt
sudo mkdir deepseek-ocr
sudo chown $USER:$USER deepseek-ocr
cd deepseek-ocr

# Copy your deepseek_ocr_server.py here
# Make sure it binds to 127.0.0.1 ONLY (not 0.0.0.0)
```

**IMPORTANT**: Modify `deepseek_ocr_server.py` to bind to localhost only:

```python
# Line 328 in deepseek_ocr_server.py - CHANGE THIS:
# app.run(host='0.0.0.0', port=5003, debug=False)

# TO THIS (localhost only):
app.run(host='127.0.0.1', port=5003, debug=False)
```

Create systemd service for OCR server:

```bash
sudo nano /etc/systemd/system/deepseek-ocr.service
```

```ini
[Unit]
Description=DeepSeek OCR Server
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/opt/deepseek-ocr
ExecStart=/usr/bin/python3 /opt/deepseek-ocr/deepseek_ocr_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable deepseek-ocr
sudo systemctl start deepseek-ocr
```

### Step 3: Deploy Gateway API

```bash
# Create directory
sudo mkdir /opt/ocr-gateway
sudo chown $USER:$USER /opt/ocr-gateway
cd /opt/ocr-gateway

# Copy gateway files
cp /path/to/secure_ocr_gateway.py ./

# Create environment file for secrets
nano .env
```

Add to `.env`:
```bash
export API_KEY_IOS="your-secure-ios-key-here-use-uuid"
export API_KEY_WEB="your-secure-web-key-here-use-uuid"
export OCR_SERVER_URL="http://127.0.0.1:5003"
export SECRET_KEY="your-flask-secret-key-here"
```

Create systemd service for gateway:

```bash
sudo nano /etc/systemd/system/ocr-gateway.service
```

```ini
[Unit]
Description=OCR Gateway API
After=network.target deepseek-ocr.service

[Service]
Type=simple
User=your-username
WorkingDirectory=/opt/ocr-gateway
EnvironmentFile=/opt/ocr-gateway/.env
ExecStart=/usr/bin/gunicorn -w 4 -b 127.0.0.1:8000 secure_ocr_gateway:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable ocr-gateway
sudo systemctl start ocr-gateway
```

### Step 4: Configure NGINX (Reverse Proxy with SSL)

```bash
sudo nano /etc/nginx/sites-available/ocr-gateway
```

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name api.yourcompany.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name api.yourcompany.com;

    # SSL Configuration (Certbot will add these)
    ssl_certificate /etc/letsencrypt/live/api.yourcompany.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourcompany.com/privkey.pem;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req zone=api_limit burst=20 nodelay;

    # Max body size (for image uploads)
    client_max_body_size 16M;

    # Proxy to gateway
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 120s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }

    # Health check (no auth required)
    location /health {
        proxy_pass http://127.0.0.1:8000/health;
        access_log off;
    }
}
```

Enable site:

```bash
sudo ln -s /etc/nginx/sites-available/ocr-gateway /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### Step 5: Get SSL Certificate

```bash
sudo certbot --nginx -d api.yourcompany.com
```

### Step 6: Configure Firewall

```bash
# Allow only necessary ports
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP (redirects to HTTPS)
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable

# Verify OCR server is NOT accessible from outside
# This should FAIL (which is what we want):
curl http://your-server-ip:5003/health
# Should fail: connection refused

# This should SUCCEED:
curl https://api.yourcompany.com/health
```

## 🔑 API Key Management

### Generate Secure API Keys:

```python
import secrets
import uuid

# Generate a secure API key
api_key = f"ios_app_{secrets.token_urlsafe(32)}"
print(f"API Key: {api_key}")

# Or use UUID
api_key = f"ios_app_{uuid.uuid4().hex}"
print(f"API Key: {api_key}")
```

### Store API Keys Securely:

**Option 1: Environment Variables**
```bash
export API_KEYS='{"key1": {"user": "ios_app", "tier": "pro", "daily_limit": 1000}}'
```

**Option 2: Database (Recommended for Production)**
- Use PostgreSQL or MySQL
- Hash API keys before storing
- Add created_at, expires_at fields
- Enable/disable keys dynamically

**Option 3: Secrets Manager**
- AWS Secrets Manager
- Azure Key Vault
- Google Cloud Secret Manager

## 📱 iOS App Configuration

1. **Store API Key in Keychain** (not hardcoded!)

```swift
import Security

class KeychainHelper {
    static func saveAPIKey(_ key: String) {
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "OCR_API_KEY",
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "OCR_API_KEY",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        if let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
```

2. **Use the OCR Client** (from ios_example.swift)

3. **Handle Errors Gracefully**

## 🔍 Monitoring & Logging

### Monitor Logs:

```bash
# Gateway logs
sudo journalctl -u ocr-gateway -f

# OCR server logs
sudo journalctl -u deepseek-ocr -f

# NGINX logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Setup Monitoring (Optional):

```bash
# Install monitoring tools
pip install prometheus-flask-exporter

# Add to gateway:
from prometheus_flask_exporter import PrometheusMetrics
metrics = PrometheusMetrics(app)
```

## 🧪 Testing

### Test from Terminal:

```bash
# Health check
curl https://api.yourcompany.com/health

# OCR test
curl -X POST https://api.yourcompany.com/api/v1/ocr \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "image": "https://upload.wikimedia.org/wikipedia/commons/0/0b/ReceiptSwiss.jpg",
    "prompt": "Extract all text."
  }'

# Check usage
curl https://api.yourcompany.com/api/v1/usage \
  -H "X-API-Key: your-api-key"
```

## 🔐 Security Checklist

- [ ] OCR server only accessible from localhost (127.0.0.1)
- [ ] Gateway behind NGINX with SSL
- [ ] API keys stored securely (not in code)
- [ ] Rate limiting enabled
- [ ] Firewall configured
- [ ] SSL certificate valid
- [ ] Logs monitored
- [ ] Regular security updates
- [ ] Input validation enabled
- [ ] File size limits set
- [ ] CORS configured (if needed for web)
- [ ] Backup strategy in place

## 🚨 Troubleshooting

### OCR server not responding:
```bash
sudo systemctl status deepseek-ocr
sudo journalctl -u deepseek-ocr -n 50
```

### Gateway errors:
```bash
sudo systemctl status ocr-gateway
tail -f /opt/ocr-gateway/ocr_gateway.log
```

### NGINX issues:
```bash
sudo nginx -t
sudo systemctl status nginx
```

## 💰 Cost Optimization

1. **Use batch endpoints** for multiple images
2. **Implement caching** for repeated images
3. **Compress images** before sending
4. **Set appropriate rate limits** per tier
5. **Monitor usage** and adjust quotas

## 📞 Support

For issues or questions:
- Check logs first
- Review security checklist
- Test with curl before blaming iOS app
- Monitor server resources (CPU, RAM, GPU)

---

**Remember**: Never expose the OCR server (port 5003) directly to the internet! Always use the gateway.


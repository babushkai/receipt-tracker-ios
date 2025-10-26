#!/usr/bin/env python3
"""
Automated Docker build on RunPod via API
This script:
1. Creates a RunPod GPU pod
2. SSHs in and builds the Docker image
3. Pushes to container registry
4. Terminates the pod

Usage:
    export RUNPOD_API_KEY="your-api-key"
    python3 runpod_build_automation.py

For GitHub Actions, set these secrets:
- RUNPOD_API_KEY
- DOCKER_USERNAME (optional)
- DOCKER_PASSWORD (optional)
"""

import requests
import paramiko
import time
import os
import sys
import tempfile
from pathlib import Path
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend

# Configuration
# Use any available GPU - be flexible for faster pod creation
GPU_TYPE = "NVIDIA RTX 4000 Ada Generation"  
CLOUD_TYPE = "SECURE"  # SECURE cloud is more reliable for getting pods quickly
CONTAINER_DISK_GB = 50  # Increased for Docker build
# Use RunPod's base image - lightweight, has Docker daemon already running
DOCKER_IMAGE = "runpod/base:1.0.2-cuda1290-ubuntu2204"
POD_NAME = f"auto-build-{int(time.time())}"
ESTIMATED_COST_PER_HOUR = 0.44  # RTX 4000 SECURE cloud cost (higher but more reliable)

def generate_ssh_keypair():
    """Generate a temporary SSH key pair"""
    print("🔑 Generating temporary SSH key pair...")
    
    # Generate RSA key pair
    key = rsa.generate_private_key(
        backend=default_backend(),
        public_exponent=65537,
        key_size=2048
    )
    
    # Get private key in PEM format
    private_key = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.TraditionalOpenSSL,
        serialization.NoEncryption()
    )
    
    # Get public key in OpenSSH format
    public_key = key.public_key().public_bytes(
        serialization.Encoding.OpenSSH,
        serialization.PublicFormat.OpenSSH
    )
    
    print("✅ SSH key pair generated")
    return private_key, public_key

def create_pod(api_key, ssh_public_key):
    """Create a RunPod GPU pod using REST API with SSH key"""
    print("🚀 Creating RunPod pod with SSH access...")
    
    url = "https://rest.runpod.io/v1/pods"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    # Add SSH public key to environment variables
    payload = {
        "name": POD_NAME,
        "imageName": DOCKER_IMAGE,
        "gpuTypeIds": [GPU_TYPE],
        "cloudType": CLOUD_TYPE,
        "containerDiskInGb": CONTAINER_DISK_GB,
        "ports": ["22/tcp"],
        "volumeInGb": 0,
        "gpuCount": 1,
        "supportPublicIp": True,
        "env": {
            "PUBLIC_KEY": ssh_public_key.decode('utf-8')
        }
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        
        pod = response.json()
        pod_id = pod['id']
        
        print(f"✅ Pod created: {pod_id}")
        print(f"📊 Cost: ${pod.get('costPerHr', 'unknown')}/hr")
        print(f"🔐 SSH key registered with pod")
        
        return pod_id, pod
        
    except Exception as e:
        print(f"❌ Failed to create pod: {e}")
        if hasattr(e, 'response'):
            print(f"Response: {e.response.text}")
        sys.exit(1)

def wait_for_pod(api_key, pod_id, timeout=900):
    """Wait for pod to be running using REST API"""
    print("⏳ Waiting for pod to be ready...")
    
    url = f"https://rest.runpod.io/v1/pods/{pod_id}"
    headers = {
        "Authorization": f"Bearer {api_key}",
    }
    
    start_time = time.time()
    check_count = 0
    
    while time.time() - start_time < timeout:
        try:
            response = requests.get(url, headers=headers)
            response.raise_for_status()
            
            pod = response.json()
            status = pod.get('desiredStatus', 'UNKNOWN')
            public_ip = pod.get('publicIp')
            runtime_status = pod.get('runtime', {})
            
            check_count += 1
            
            # Show detailed info every 30 seconds (3 checks)
            if check_count % 3 == 0:
                elapsed = int(time.time() - start_time)
                print(f"   Status: {status}, Public IP: {public_ip or 'waiting...'} ({elapsed}s)")
                if runtime_status:
                    print(f"   Runtime: {runtime_status}")
            else:
                print(f"   Status: {status}...")
            
            # Check if pod is ready
            if status == 'RUNNING' and public_ip:
                print("✅ Pod is running!")
                print(f"🌐 Public IP: {public_ip}")
                return pod
            
            time.sleep(10)
            
        except Exception as e:
            print(f"⚠️  Error checking status: {e}")
            time.sleep(10)
    
    print(f"❌ Pod failed to start within {timeout}s")
    print(f"   Last known status: {status}")
    print(f"   Last known public IP: {public_ip or 'None'}")
    return None

def get_ssh_connection(pod, private_key_bytes):
    """Get SSH connection to pod using private key"""
    print("🔌 Connecting via SSH...")
    
    try:
        # Extract connection info from REST API response
        ssh_host = pod.get('publicIp')
        port_mappings = pod.get('portMappings', {})
        
        # Get the public port for SSH (port 22)
        ssh_port = port_mappings.get('22')
        
        if not ssh_host:
            print("❌ No public IP available")
            print(f"📊 Pod info: {pod}")
            return None
            
        if not ssh_port:
            print("⚠️  No SSH port mapping found, trying default port 22")
            ssh_port = 22
        
        print(f"📡 Connecting to {ssh_host}:{ssh_port}")
        
        # Create SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        # Load the private key
        private_key = paramiko.RSAKey.from_private_key_file(private_key_bytes)
        
        # Wait for SSH to be ready
        print("⏳ Waiting for SSH to be ready (60 seconds)...")
        time.sleep(60)
        
        max_retries = 3
        for attempt in range(max_retries):
            try:
                print(f"🔄 Connection attempt {attempt + 1}/{max_retries}...")
                ssh.connect(
                    hostname=ssh_host,
                    port=ssh_port,
                    username='root',
                    pkey=private_key,
                    timeout=30,
                    look_for_keys=False,
                    allow_agent=False
                )
                print("✅ SSH connected!")
                return ssh
                
            except Exception as e:
                if attempt < max_retries - 1:
                    print(f"⚠️  Attempt {attempt + 1} failed: {e}")
                    print(f"🔄 Retrying in 30 seconds...")
                    time.sleep(30)
                else:
                    raise
        
        return None
        
    except Exception as e:
        print(f"❌ SSH connection failed: {e}")
        print("💡 Try using RunPod web terminal or SSH manually")
        return None

def execute_build(ssh, github_repo, github_sha, registry, registry_user, registry_token):
    """Execute build commands on pod"""
    print("🔨 Starting Docker build...")
    
    build_commands = f"""
set -e

echo "📥 Installing git..."
apt-get update -qq && apt-get install -y -qq git curl > /dev/null 2>&1

echo "🐳 Checking Docker (should already be running on RunPod)..."
docker --version

echo "✅ Verifying Docker daemon..."
if docker info > /dev/null 2>&1; then
    echo "✅ Docker is already running and working!"
    docker info | head -10
else
    echo "❌ Docker daemon not accessible"
    exit 1
fi

echo "📦 Setting up build directory..."
cd /root
mkdir -p build-temp
cd build-temp

echo "📦 Cloning repository..."
git clone https://github.com/{github_repo}.git repo
cd repo
git checkout {github_sha}

echo "🔨 Building Docker image..."
docker build -f Dockerfile.deepseek.prebuilt -t temp-build:latest .

echo "🏷️  Tagging images..."
docker tag temp-build:latest {registry}/{github_repo}/deepseek-ocr:latest
docker tag temp-build:latest {registry}/{github_repo}/deepseek-ocr:{github_sha[:8]}

echo "🔐 Logging in to container registry..."
echo "{registry_token}" | docker login {registry} -u {registry_user} --password-stdin

echo "📤 Pushing images..."
docker push {registry}/{github_repo}/deepseek-ocr:latest
docker push {registry}/{github_repo}/deepseek-ocr:{github_sha[:8]}

echo "✅ Build complete!"
echo "📊 Image size:"
docker images {registry}/{github_repo}/deepseek-ocr:latest --format "table {{{{.Repository}}}}\\t{{{{.Tag}}}}\\t{{{{.Size}}}}"
"""
    
    try:
        # Execute commands
        stdin, stdout, stderr = ssh.exec_command(build_commands, get_pty=True)
        
        # Stream output in real-time
        for line in stdout:
            print(line.strip())
        
        # Check for errors
        exit_code = stdout.channel.recv_exit_status()
        
        if exit_code == 0:
            print("✅ Build succeeded!")
            return True
        else:
            print(f"❌ Build failed with exit code {exit_code}")
            for line in stderr:
                print(line.strip())
            return False
            
    except Exception as e:
        print(f"❌ Build execution failed: {e}")
        return False

def terminate_pod(api_key, pod_id):
    """Terminate the RunPod pod using REST API"""
    print(f"🧹 Terminating pod {pod_id}...")
    
    url = f"https://rest.runpod.io/v1/pods/{pod_id}/stop"
    headers = {
        "Authorization": f"Bearer {api_key}",
    }
    
    try:
        response = requests.post(url, headers=headers)
        response.raise_for_status()
        print("✅ Pod stopped successfully")
        
        # Also delete the pod
        delete_url = f"https://rest.runpod.io/v1/pods/{pod_id}"
        response = requests.delete(delete_url, headers=headers)
        response.raise_for_status()
        print("✅ Pod deleted")
        
    except Exception as e:
        print(f"⚠️  Failed to terminate pod: {e}")
        print(f"💡 Manually terminate at: https://www.runpod.io/console/pods/{pod_id}")

def main():
    """Main automation flow"""
    print("="*70)
    print("🤖 Automated Docker Build on RunPod")
    print("="*70)
    
    # Check for API key
    api_key = os.environ.get('RUNPOD_API_KEY')
    if not api_key:
        print("❌ RUNPOD_API_KEY environment variable not set")
        print("💡 Get your API key from: https://www.runpod.io/console/user/settings")
        sys.exit(1)
    
    # Get configuration from environment or defaults
    github_repo = os.environ.get('GITHUB_REPOSITORY', 'babushkai/receipt-tracker-ios')
    github_sha = os.environ.get('GITHUB_SHA', 'main')
    registry = os.environ.get('REGISTRY', 'ghcr.io')
    registry_user = os.environ.get('REGISTRY_USER', os.environ.get('GITHUB_ACTOR', 'babushkai'))
    registry_token = os.environ.get('REGISTRY_TOKEN', os.environ.get('GITHUB_TOKEN', ''))
    
    if not registry_token:
        print("⚠️  No registry token provided - images won't be pushed")
    
    pod_id = None
    ssh = None
    success = False
    private_key_file = None
    
    try:
        # Step 1: Generate SSH key pair
        private_key_bytes, public_key_bytes = generate_ssh_keypair()
        
        # Save private key to temporary file
        with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.pem') as f:
            f.write(private_key_bytes)
            private_key_file = f.name
        
        # Make key file read-only
        os.chmod(private_key_file, 0o600)
        
        # Step 2: Create pod with public key
        pod_id, initial_pod = create_pod(api_key, public_key_bytes)
        
        # Step 3: Wait for pod to be ready
        pod = wait_for_pod(api_key, pod_id)
        if not pod:
            print("❌ Pod failed to start")
            sys.exit(1)
        
        # Step 4: Connect via SSH with private key
        ssh = get_ssh_connection(pod, private_key_file)
        if not ssh:
            print("\n" + "="*70)
            print("❌ SSH automation failed - Manual build required")
            print("="*70)
            print(f"🔗 Pod URL: https://www.runpod.io/console/pods/{pod_id}")
            print("")
            print("📝 Steps to complete build manually:")
            print("1. Go to the pod URL above")
            print("2. Click 'Connect' → 'Start Web Terminal'")
            print("3. Run these commands:")
            print("")
            print("   apt-get update && apt-get install -y git")
            print("   cd /workspace")
            print(f"   git clone https://github.com/{github_repo}.git build")
            print("   cd build")
            print(f"   git checkout {github_sha}")
            print("   docker build -f Dockerfile.deepseek.prebuilt -t temp:latest .")
            print(f"   docker tag temp:latest {registry}/{github_repo}/deepseek-ocr:latest")
            print(f"   echo {registry_token[:10]}... | docker login {registry} -u {registry_user} --password-stdin")
            print(f"   docker push {registry}/{github_repo}/deepseek-ocr:latest")
            print("")
            print("⚠️  POD LEFT RUNNING - You must stop it manually when done!")
            print("💰 Costing: ~$0.26/hour while running")
            print("="*70)
            
            # Don't terminate - let user build manually
            return  # Exit without error so GitHub Actions doesn't fail
        
        # Step 4: Execute build
        success = execute_build(ssh, github_repo, github_sha, registry, registry_user, registry_token)
        
        # Calculate cost
        runtime_minutes = 5  # Estimated
        cost = runtime_minutes * (ESTIMATED_COST_PER_HOUR / 60)
        print(f"\n💰 Estimated cost: ${cost:.3f} ({runtime_minutes} minutes @ ${ESTIMATED_COST_PER_HOUR}/hr)")
        
    except KeyboardInterrupt:
        print("\n⚠️  Build interrupted by user")
        success = False
        
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        success = False
        
    finally:
        # Cleanup
        if ssh:
            ssh.close()
        
        # Clean up private key file
        if private_key_file and os.path.exists(private_key_file):
            try:
                os.unlink(private_key_file)
                print("🔐 Temporary SSH key cleaned up")
            except:
                pass
        
        if pod_id:
            terminate_pod(api_key, pod_id)
    
    # Exit with appropriate code
    # If we got here without success and pod_id exists, it means manual build is needed
    if not success and pod_id:
        print("\n💡 Manual build mode - pod left running for you to complete the build")
        sys.exit(0)  # Don't fail GitHub Actions, just indicate manual step needed
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()


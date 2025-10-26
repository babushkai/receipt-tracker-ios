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

import runpod
import paramiko
import time
import os
import sys
from pathlib import Path

# Configuration
GPU_TYPE = "NVIDIA RTX 4000 Ada Generation"
CLOUD_TYPE = "COMMUNITY"  # COMMUNITY cloud automatically uses spot pricing
CONTAINER_DISK_GB = 30
DOCKER_IMAGE = "runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04"
POD_NAME = f"auto-build-{int(time.time())}"
ESTIMATED_COST_PER_HOUR = 0.26  # RTX 4000 Ada COMMUNITY cloud cost

def create_pod():
    """Create a RunPod GPU pod"""
    print("🚀 Creating RunPod pod...")
    
    try:
        pod = runpod.create_pod(
            name=POD_NAME,
            image_name=DOCKER_IMAGE,
            gpu_type_id=GPU_TYPE,
            cloud_type="COMMUNITY",  # COMMUNITY cloud automatically uses spot pricing
            container_disk_in_gb=CONTAINER_DISK_GB,
            ports="22/tcp",  # SSH access
            volume_in_gb=0,  # No persistent volume needed
        )
        
        pod_id = pod['id']
        print(f"✅ Pod created: {pod_id}")
        return pod_id
        
    except Exception as e:
        print(f"❌ Failed to create pod: {e}")
        sys.exit(1)

def wait_for_pod(pod_id, timeout=300):
    """Wait for pod to be running"""
    print("⏳ Waiting for pod to be ready...")
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        try:
            pod = runpod.get_pod(pod_id)
            status = pod.get('desiredStatus', 'UNKNOWN')
            
            if status == 'RUNNING':
                print("✅ Pod is running!")
                return pod
            
            print(f"   Status: {status}...")
            time.sleep(10)
            
        except Exception as e:
            print(f"⚠️  Error checking status: {e}")
            time.sleep(10)
    
    print(f"❌ Pod failed to start within {timeout}s")
    return None

def get_ssh_connection(pod_id):
    """Get SSH connection to pod"""
    print("🔌 Connecting via SSH...")
    
    try:
        # Get updated pod info with connection details
        print("📡 Fetching pod connection info...")
        pod = runpod.get_pod(pod_id)
        
        # Extract connection info from updated pod data
        machine = pod.get('machine', {})
        
        # Try different fields for SSH connection
        ssh_host = machine.get('publicIp') or machine.get('podHostId')
        ssh_port = None
        
        # Look for SSH port in various places
        if 'ports' in machine:
            ports = machine['ports']
            if '22/tcp' in ports:
                port_info = ports['22/tcp']
                if isinstance(port_info, list) and len(port_info) > 0:
                    ssh_port = port_info[0].get('publicPort')
                elif isinstance(port_info, dict):
                    ssh_port = port_info.get('publicPort')
        
        # Check runtime info for SSH
        if not ssh_port:
            runtime = pod.get('runtime', {})
            ports = runtime.get('ports', [])
            for port in ports:
                if port.get('privatePort') == 22:
                    ssh_port = port.get('publicPort')
                    break
        
        if not ssh_host:
            print("❌ No SSH host available")
            print(f"📊 Pod info: {pod}")
            return None
            
        if not ssh_port:
            print("⚠️  No SSH port found, trying default port 22")
            ssh_port = 22
        
        print(f"📡 Connecting to {ssh_host}:{ssh_port}")
        
        # Create SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        # RunPod uses root with SSH keys
        # Wait a bit for SSH to be ready
        print("⏳ Waiting for SSH to be ready...")
        time.sleep(30)
        
        try:
            ssh.connect(
                hostname=ssh_host,
                port=ssh_port,
                username='root',
                timeout=30,
                look_for_keys=False,
                allow_agent=False
            )
        except Exception as e:
            print(f"⚠️  First connection attempt failed: {e}")
            print("🔄 Retrying in 30 seconds...")
            time.sleep(30)
            ssh.connect(
                hostname=ssh_host,
                port=ssh_port,
                username='root',
                timeout=30,
                look_for_keys=False,
                allow_agent=False
            )
        
        print("✅ SSH connected!")
        return ssh
        
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
apt-get update -qq && apt-get install -y -qq git > /dev/null 2>&1

echo "📦 Cloning repository..."
cd /workspace
git clone https://github.com/{github_repo}.git build
cd build
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

def terminate_pod(pod_id):
    """Terminate the RunPod pod"""
    print(f"🧹 Terminating pod {pod_id}...")
    
    try:
        runpod.stop_pod(pod_id)
        print("✅ Pod terminated")
    except Exception as e:
        print(f"⚠️  Failed to terminate pod: {e}")
        print(f"💡 Manually terminate at: https://www.runpod.io/console/pods")

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
    
    runpod.api_key = api_key
    
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
    
    try:
        # Step 1: Create pod
        pod_id = create_pod()
        
        # Step 2: Wait for pod to be ready
        pod = wait_for_pod(pod_id)
        if not pod:
            print("❌ Pod failed to start")
            sys.exit(1)
        
        # Step 3: Connect via SSH
        ssh = get_ssh_connection(pod_id)
        if not ssh:
            print("❌ Failed to establish SSH connection")
            print("💡 Alternative: Use RunPod web terminal to build manually")
            print(f"🔗 Pod URL: https://www.runpod.io/console/pods/{pod_id}")
            sys.exit(1)
        
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
        
        if pod_id:
            terminate_pod(pod_id)
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()


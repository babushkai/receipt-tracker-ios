# RunPod API Updates

## Recent Changes (2025)

### Cloud Type Parameter

**Old API** (deprecated):
```python
pod = runpod.create_pod(
    cloud_type="SPOT"  # ❌ No longer valid
)
```

**New API** (current):
```python
pod = runpod.create_pod(
    cloud_type="COMMUNITY",  # ✅ Use this
    bid_per_gpu=0.26,  # Set max bid for spot pricing
)
```

### Valid Cloud Types

1. **`COMMUNITY`** - Community cloud (includes spot instances)
   - Cheapest option
   - Spot pricing with bid system
   - May be interrupted
   - **Recommended for CI/CD builds**

2. **`SECURE`** - Secure cloud
   - Dedicated hardware
   - More expensive
   - More reliable
   - Good for production workloads

3. **`ALL`** - Try all clouds
   - Will use any available
   - Not recommended for automated scripts

### Spot Pricing with COMMUNITY Cloud

To get spot prices, use `COMMUNITY` cloud + set `bid_per_gpu`:

```python
pod = runpod.create_pod(
    name="my-pod",
    cloud_type="COMMUNITY",
    bid_per_gpu=0.30,  # Max you're willing to pay per hour
    gpu_type_id="NVIDIA RTX 4000 Ada Generation",
    # ... other params
)
```

**Current spot prices** (as of Oct 2025):
- RTX 4000 Ada: ~$0.26/hr
- RTX 4090: ~$0.25/hr
- A5000: ~$0.19/hr

## Updated Scripts

The following files have been updated:
- ✅ `scripts/runpod_build_automation.py` - Uses `COMMUNITY` + `bid_per_gpu`
- ✅ `.github/workflows/build-on-runpod-automated.yml` - Updated config

## Migration Guide

If you have custom scripts using the old API:

**Replace**:
```python
cloud_type="SPOT"
```

**With**:
```python
cloud_type="COMMUNITY",
bid_per_gpu=0.30  # Your max bid
```

## Reference

- [RunPod API Documentation](https://docs.runpod.io/reference/create-pod)
- [RunPod Python SDK](https://github.com/runpod/runpod-python)


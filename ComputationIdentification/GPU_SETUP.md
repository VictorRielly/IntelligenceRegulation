# GPU Setup Guide

## Checking GPU Availability

```python
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A'}")
```

## Installing GPU Support

### PyTorch with CUDA

**For CUDA 11.8:**
```powershell
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

**For CUDA 12.1:**
```powershell
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

### Quantization Support (Optional but Recommended)

For large models, install bitsandbytes for 4-bit/8-bit quantization:

```powershell
pip install bitsandbytes
```

## Model Size and GPU Memory

| Model Size | Full Precision | 8-bit | 4-bit |
|------------|----------------|-------|-------|
| 2.7B       | ~6 GB          | ~3 GB | ~2 GB |
| 7B         | ~14 GB         | ~7 GB | ~4 GB |
| 13B        | ~26 GB         | ~13 GB| ~7 GB |

## Recommended Configurations

### 8GB GPU (e.g., RTX 3060, RTX 3070)
```powershell
# Use 4-bit quantization for 7B models
python chat.py mistral-7b --4bit

# Or use smaller models
python chat.py phi-2
```

### 16GB GPU (e.g., RTX 3080, RTX 4070)
```powershell
# 7B models with 8-bit
python chat.py mistral-7b --8bit

# 13B models with 4-bit
python chat.py llama2-13b --4bit
```

### 24GB+ GPU (e.g., RTX 3090, RTX 4090, A100)
```powershell
# 7B models full precision
python chat.py mistral-7b

# 13B models with 8-bit
python chat.py llama2-13b --8bit
```

## Troubleshooting

### Out of Memory Errors

1. **Use quantization:**
   ```powershell
   python chat.py mistral-7b --4bit
   ```

2. **Use a smaller model:**
   ```powershell
   python chat.py phi-2
   ```

3. **Reduce max_length in chat.py** (default is 100)

### CUDA Not Detected

1. Check NVIDIA driver: `nvidia-smi`
2. Verify PyTorch CUDA version matches system CUDA
3. Reinstall PyTorch with correct CUDA version

### Quantization Not Working

1. Install bitsandbytes: `pip install bitsandbytes`
2. On Windows, may need to install from source or use WSL
3. Check CUDA compatibility

## Performance Tips

1. **Use 4-bit quantization** for best memory efficiency with minimal quality loss
2. **Batch size**: The chat interface processes one at a time, so memory usage is optimal
3. **First run**: Models download on first use (10-30 minutes depending on size)
4. **Subsequent runs**: Models are cached, loading is much faster


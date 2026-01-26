# GPU Installation Guide for RTX 4070

## Your System
- **GPU**: NVIDIA GeForce RTX 4070 (8GB VRAM)
- **CUDA Version**: 12.7
- **Driver**: 566.14

## Quick Fix

Run the installation script:

```powershell
cd ComputationIdentification
.\install_pytorch_cuda.ps1
```

## Manual Installation

If the script doesn't work, install manually:

### Step 1: Uninstall CPU-only PyTorch

```powershell
.\venv\Scripts\python.exe -m pip uninstall torch torchvision torchaudio -y
```

### Step 2: Install PyTorch with CUDA 12.1

```powershell
.\venv\Scripts\python.exe -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

### Step 3: Verify Installation

```powershell
.\venv\Scripts\python.exe -c "import torch; print('CUDA available:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')"
```

## Expected Output

You should see:
```
CUDA available: True
GPU: NVIDIA GeForce RTX 4070
```

## Recommended Models for RTX 4070 (8GB)

With 8GB VRAM, you can run:

**With 4-bit quantization (recommended):**
```powershell
python chat.py mistral-7b --4bit
python chat.py llama2-7b --4bit
```

**Smaller models (full precision):**
```powershell
python chat.py phi-2
```

**Note**: 13B models may be too large even with 4-bit quantization on 8GB VRAM.

## Troubleshooting

### If CUDA is still not available:

1. **Check NVIDIA drivers are up to date:**
   ```powershell
   nvidia-smi
   ```

2. **Verify CUDA toolkit is installed:**
   - PyTorch includes CUDA runtime, but you may need CUDA toolkit for some operations
   - Download from: https://developer.nvidia.com/cuda-downloads

3. **Try CUDA 11.8 version instead:**
   ```powershell
   .\venv\Scripts\python.exe -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
   ```

4. **Check PyTorch installation:**
   ```powershell
   .\venv\Scripts\python.exe -c "import torch; print(torch.__version__); print(torch.cuda.is_available())"
   ```

### If you get "CUDA out of memory" errors:

- Use 4-bit quantization: `--4bit`
- Use smaller models: `phi-2` or `gpt-neo-2.7b`
- Reduce max_length in chat.py (default is 100)



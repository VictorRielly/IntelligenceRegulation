# Environment Setup Guide

This guide will help you set up a conda environment with GPU support for running the model activation extraction scripts.

## Prerequisites

1. **Anaconda or Miniconda** installed on your system
   - Download from: https://www.anaconda.com/products/distribution
   - Or Miniconda: https://docs.conda.io/en/latest/miniconda.html

2. **NVIDIA GPU** with CUDA support
   - Check your CUDA version: `nvidia-smi`
   - PyTorch supports CUDA 11.8 and 12.1

## Quick Setup (Windows PowerShell)

1. Open PowerShell in the `ComputationIdentification` directory

2. Run the setup script:
   ```powershell
   .\setup_environment.ps1
   ```

## Manual Setup

### Step 1: Create the Conda Environment

```bash
conda create -n intelligence-regulation python=3.10 -y
```

### Step 2: Activate the Environment

**Windows (PowerShell/CMD):**
```powershell
conda activate intelligence-regulation
```

**Linux/Mac:**
```bash
conda activate intelligence-regulation
```

### Step 3: Install PyTorch with GPU Support

**For CUDA 11.8:**
```bash
conda install pytorch pytorch-cuda=11.8 -c pytorch -c nvidia -y
```

**For CUDA 12.1:**
```bash
conda install pytorch pytorch-cuda=12.1 -c pytorch -c nvidia -y
```

**To check your CUDA version:**
```bash
nvidia-smi
```

### Step 4: Install Additional Dependencies

```bash
pip install transformers>=4.30.0 accelerate>=0.20.0 huggingface-hub
```

Or install from requirements.txt:
```bash
pip install -r requirements.txt
```

## Verify GPU Support

After setup, verify that PyTorch can detect your GPU:

```python
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda}'); print(f'GPU device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"
```

Expected output:
```
CUDA available: True
CUDA version: 11.8
GPU device: [Your GPU Name]
```

## Using the Environment

1. **Activate the environment:**
   ```bash
   conda activate intelligence-regulation
   ```

2. **Run the script:**
   ```bash
   python model_activations.py
   ```

3. **Deactivate when done:**
   ```bash
   conda deactivate
   ```

## Troubleshooting

### GPU Not Detected

1. **Check CUDA installation:**
   ```bash
   nvidia-smi
   ```

2. **Verify PyTorch CUDA version matches system CUDA:**
   ```python
   import torch
   print(torch.version.cuda)
   ```

3. **Reinstall PyTorch with correct CUDA version:**
   ```bash
   conda uninstall pytorch pytorch-cuda
   conda install pytorch pytorch-cuda=11.8 -c pytorch -c nvidia -y
   ```

### Out of Memory Errors

- Use a smaller model or reduce batch size
- Consider using CPU if GPU memory is insufficient:
  ```python
  model_wrapper = ModelWithActivations(model_name="EleutherAI/gpt-neo-1.3B", device="cpu")
  ```

## Alternative: Using environment.yml

You can also create the environment directly from the YAML file:

```bash
conda env create -f environment.yml
conda activate intelligence-regulation
```

Note: You may need to edit `environment.yml` to match your CUDA version.


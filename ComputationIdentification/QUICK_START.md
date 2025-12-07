# Quick Start Guide

## Option 1: Run the Installation and Script Automatically

Run this PowerShell script to install everything and run the model:

```powershell
cd ComputationIdentification
.\install_and_run.ps1
```

## Option 2: Manual Installation

### Step 1: Install Packages

**For CPU (faster download, ~500 MB):**
```powershell
cd ComputationIdentification
.\venv\Scripts\python.exe -m pip install torch torchvision torchaudio
.\venv\Scripts\python.exe -m pip install transformers>=4.30.0 accelerate>=0.20.0 huggingface-hub
```

**For GPU with CUDA 11.8 (larger download, ~2.8 GB):**
```powershell
cd ComputationIdentification
.\venv\Scripts\python.exe -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
.\venv\Scripts\python.exe -m pip install transformers>=4.30.0 accelerate>=0.20.0 huggingface-hub
```

### Step 2: Run the Script

```powershell
.\venv\Scripts\python.exe model_activations.py
```

## Verify Installation

Check if packages are installed:
```powershell
.\venv\Scripts\python.exe -c "import torch; import transformers; print('Success!')"
```

## Note

- The first run will download the model (~5 GB), which may take time
- CPU version works fine for testing, but GPU is recommended for actual use
- If you have an NVIDIA GPU, use the CUDA version for better performance


# PowerShell script for creating a virtual environment with GPU support (alternative to conda)

Write-Host "Creating Python virtual environment 'venv' with GPU support..." -ForegroundColor Green

# Create virtual environment
python -m venv venv

# Activate the environment
.\venv\Scripts\Activate.ps1

# Upgrade pip
python -m pip install --upgrade pip

# Install PyTorch with CUDA support
# For CUDA 11.8:
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# For CUDA 12.1, use:
# pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# For CPU only (if no GPU), use:
# pip install torch torchvision torchaudio

# Install other dependencies
pip install transformers>=4.30.0 accelerate>=0.20.0 huggingface-hub

Write-Host ""
Write-Host "Environment setup complete!" -ForegroundColor Green
Write-Host "To activate the environment, run: .\venv\Scripts\Activate.ps1" -ForegroundColor Yellow
Write-Host "To verify GPU support, run: python -c 'import torch; print(torch.cuda.is_available())'" -ForegroundColor Yellow


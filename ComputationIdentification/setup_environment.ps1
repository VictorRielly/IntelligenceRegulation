# PowerShell script for creating the conda environment with GPU support on Windows

Write-Host "Creating conda environment 'intelligence-regulation' with GPU support..." -ForegroundColor Green

# Create conda environment with Python 3.10
conda create -n intelligence-regulation python=3.10 -y

# Activate the environment
conda activate intelligence-regulation

# Install PyTorch with CUDA support
# For CUDA 11.8:
conda install pytorch pytorch-cuda=11.8 -c pytorch -c nvidia -y

# For CUDA 12.1, uncomment the line below and comment the line above:
# conda install pytorch pytorch-cuda=12.1 -c pytorch -c nvidia -y

# Install other dependencies via pip
pip install transformers>=4.30.0 accelerate>=0.20.0 huggingface-hub

Write-Host ""
Write-Host "Environment setup complete!" -ForegroundColor Green
Write-Host "To activate the environment, run: conda activate intelligence-regulation" -ForegroundColor Yellow
Write-Host "To verify GPU support, run: python -c 'import torch; print(torch.cuda.is_available())'" -ForegroundColor Yellow


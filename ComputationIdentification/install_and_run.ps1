# Script to install dependencies and run model_activations.py

Write-Host "Installing required packages..." -ForegroundColor Green
Write-Host "This may take several minutes, especially for PyTorch..." -ForegroundColor Yellow

# Install PyTorch (CPU version - smaller download, can upgrade to GPU later)
Write-Host "`nInstalling PyTorch (CPU version)..." -ForegroundColor Cyan
.\venv\Scripts\python.exe -m pip install torch torchvision torchaudio

# Install transformers and other dependencies
Write-Host "`nInstalling transformers and dependencies..." -ForegroundColor Cyan
.\venv\Scripts\python.exe -m pip install transformers>=4.30.0 accelerate>=0.20.0 huggingface-hub

Write-Host "`nInstallation complete! Verifying..." -ForegroundColor Green
.\venv\Scripts\python.exe -c "import torch; import transformers; print('✓ All packages installed successfully!')"

Write-Host "`nRunning model_activations.py..." -ForegroundColor Green
.\venv\Scripts\python.exe model_activations.py


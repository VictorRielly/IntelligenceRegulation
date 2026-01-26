# Script to install PyTorch with CUDA support for NVIDIA GPU

Write-Host "Installing PyTorch with CUDA 12.1 support..." -ForegroundColor Green
Write-Host "Your GPU: NVIDIA GeForce RTX 4070 (CUDA 12.7)" -ForegroundColor Cyan
Write-Host ""

# Uninstall existing PyTorch (CPU version)
Write-Host "Uninstalling existing PyTorch..." -ForegroundColor Yellow
.\venv\Scripts\python.exe -m pip uninstall torch torchvision torchaudio -y

# Install PyTorch with CUDA 12.1 support
Write-Host ""
Write-Host "Installing PyTorch with CUDA 12.1..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Yellow
.\venv\Scripts\python.exe -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Green
.\venv\Scripts\python.exe -c "import torch; print('PyTorch version:', torch.__version__); print('CUDA available:', torch.cuda.is_available()); print('CUDA version:', torch.version.cuda if torch.cuda.is_available() else 'N/A'); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')"

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "You can now run: python chat.py mistral-7b --4bit" -ForegroundColor Cyan



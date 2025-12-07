# Installing Conda

Since conda is not currently installed on your system, you have two options:

## Option 1: Install Miniconda (Recommended)

1. **Download Miniconda for Windows:**
   - Visit: https://docs.conda.io/en/latest/miniconda.html
   - Download the Windows 64-bit installer

2. **Install Miniconda:**
   - Run the installer
   - Check "Add Miniconda3 to my PATH environment variable" during installation
   - Or manually add it to PATH after installation

3. **Restart your terminal/PowerShell** after installation

4. **Verify installation:**
   ```powershell
   conda --version
   ```

5. **Then run the setup script:**
   ```powershell
   cd ComputationIdentification
   .\setup_environment.ps1
   ```

## Option 2: Use Python venv (No Conda Required)

If you prefer not to install conda, you can use Python's built-in venv:

1. **Run the venv setup script:**
   ```powershell
   cd ComputationIdentification
   .\setup_venv.ps1
   ```

2. **Activate the environment:**
   ```powershell
   .\venv\Scripts\Activate.ps1
   ```

3. **Verify GPU support:**
   ```powershell
   python -c "import torch; print(torch.cuda.is_available())"
   ```

## Which Should You Choose?

- **Conda**: Better for managing complex dependencies, multiple Python versions, and scientific computing packages
- **venv**: Simpler, built into Python, lighter weight, but requires manual CUDA setup

Both will work for this project!


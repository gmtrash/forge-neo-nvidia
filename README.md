# Ansible Deployment for Ubuntu Desktop + Stable Diffusion Forge CUDA

Automated Ansible playbooks for setting up a fresh Ubuntu installation with NVIDIA drivers, CUDA toolkit, and Stable Diffusion WebUI Forge.

## Target System

- **OS**: Ubuntu 22.04 LTS (Jammy) or newer
- **GPU**: NVIDIA RTX 5060 Ti (or any CUDA-compatible GPU)
- **Architecture**: x86_64

## Quick Start

### 1. Install Ansible on Fresh Ubuntu

```bash
sudo apt update
sudo apt install -y ansible git
```

### 2. Clone this repository

```bash
git clone <your-repo-url> forge-neo
cd forge-neo
```

### 3. Configure your settings

Edit `group_vars/localhost.yml` to customize:
- Username and user preferences
- NVIDIA driver version
- CUDA version
- Model directories
- Optional applications

**Important**: Update at minimum:
```yaml
username: your_username  # Change this!
git_user_email: "your.email@example.com"  # Change this!
```

### 4. Run the playbook

```bash
# Dry run (check mode)
ansible-playbook main.yml --check

# Actually apply
ansible-playbook main.yml

# Reboot after installation (REQUIRED for NVIDIA drivers!)
sudo reboot
```

### 5. Verify and Launch

After reboot:

```bash
# Verify NVIDIA driver
nvidia-smi

# Verify CUDA
nvcc --version

# Activate Forge environment
conda activate forge-cuda

# Verify PyTorch CUDA
python -c "import torch; print(torch.cuda.is_available())"

# Launch Stable Diffusion Forge
forge-launch
# OR
cd ~/llm/sd-webui-forge && ./launch-cuda.sh
```

Access WebUI at: **http://localhost:7860**

## What Gets Installed

### Base System (`base-system` role)
- Build essentials (gcc, make, cmake)
- Git, curl, wget, htop, vim, tmux
- Python 3 development packages
- Common utilities

### NVIDIA/CUDA (`nvidia-cuda` role)
- NVIDIA proprietary drivers (550+) from graphics-drivers PPA
- CUDA Toolkit 12.6
- cuDNN 9 for deep learning
- Environment variables and PATH configuration
- GPU monitoring utilities

### Conda (`conda` role)
- Miniforge (conda-forge by default)
- Configured in ~/.bashrc
- Auto-activation optional

### SD Forge CUDA (`forge-cuda` role)
- Clones/updates SD WebUI Forge repository
- Creates `forge-cuda` conda environment
- Installs PyTorch with CUDA 12.1 support
- Configures launch scripts
- Sets up model directories
- Creates desktop launcher

### Desktop Preferences (`desktop-preferences` role)
- Custom bash aliases (gpu, forge, forge-launch, etc.)
- Git configuration
- vim and tmux configuration
- GPU monitoring script
- Environment variables for CUDA

## Playbook Structure

```
forge-neo/
├── README.md                    # This file
├── main.yml                     # Main playbook
├── update.yml                   # Update existing installation
├── backup.yml                   # Create backups
├── test.yml                     # Test configuration
├── ansible.cfg                  # Ansible configuration
├── inventory.ini                # Inventory file
├── group_vars/
│   └── localhost.yml            # Configuration variables
└── roles/
    ├── base-system/             # System packages
    ├── nvidia-cuda/             # NVIDIA drivers + CUDA
    ├── conda/                   # Conda installation
    ├── forge-cuda/              # Stable Diffusion Forge
    └── desktop-preferences/     # User environment
```

## Available Tags

Run specific parts of the playbook:

```bash
# Install only NVIDIA drivers and CUDA
ansible-playbook main.yml --tags nvidia

# Install only SD Forge
ansible-playbook main.yml --tags forge

# Install base system + NVIDIA
ansible-playbook main.yml --tags "base,nvidia"

# Skip desktop preferences
ansible-playbook main.yml --skip-tags desktop

# Multiple specific components
ansible-playbook main.yml --tags "nvidia,conda,forge"
```

**All available tags:**
- `base` - Base system packages
- `nvidia` - NVIDIA drivers and CUDA toolkit
- `conda` - Conda/Miniforge setup
- `forge` - SD WebUI Forge with CUDA
- `desktop` - Desktop preferences and dotfiles

## Helpful Aliases (Automatically Configured)

After installation, these bash aliases are available:

- `gpu` - Show GPU status (nvidia-smi)
- `gpuw` - Watch GPU status in real-time (watch nvidia-smi)
- `nvidia-check` - Quick NVIDIA driver verification
- `torch-check` - Verify PyTorch CUDA support
- `forge` - Navigate to Forge directory and activate conda
- `forge-launch` - Launch Stable Diffusion Forge WebUI
- `conda-info` - Show conda environments
- `gpu-monitor` - Run GPU monitoring script from ~/bin

## Configuration Variables

### Key settings in `group_vars/localhost.yml`:

```yaml
# User Configuration
username: aubreybailey
home_dir: "/home/{{ username }}"

# NVIDIA/CUDA Configuration
nvidia_driver_version: 550       # Driver version
cuda_version: "12.6"             # CUDA toolkit version
cuda_compute_capability: "8.9"   # For RTX 5060 Ti

# Forge Configuration
forge_repo_url: "https://github.com/lllyasviel/stable-diffusion-webui-forge"
forge_branch: "main"
forge_install_dir: "{{ home_dir }}/llm/sd-webui-forge"
forge_conda_env: "forge-cuda"
forge_python_version: "3.11.9"

# Launch script settings
forge_commandline_args: >-
  --xformers
  --no-download-sd-model
  --listen
  --enable-insecure-extension-access

# Optional: shared model directory
# shared_models_dir: "/mnt/data/ai-models"
# shared_models_types:
#   - Stable-diffusion
#   - Lora
#   - VAE
```

### CUDA Compute Capability by GPU

Update `cuda_compute_capability` for your GPU:

- RTX 40xx/50xx (Ada Lovelace): `8.9`
- RTX 30xx (Ampere): `8.6`
- RTX 20xx (Turing): `7.5`
- GTX 10xx (Pascal): `6.1`

## Updating Your Installation

```bash
# Update Forge repository and conda environment
ansible-playbook update.yml

# Or update everything
ansible-playbook main.yml

# Update only specific component
ansible-playbook main.yml --tags forge
```

## Idempotency

All tasks are idempotent - safe to run multiple times:
- Packages only install if missing
- Config files only update if changed
- Conda environments only create if missing
- NVIDIA drivers only install if not present

## Troubleshooting

### NVIDIA Driver Not Loading

**Symptom**: `nvidia-smi` fails with "couldn't communicate with driver"

**Solution**: Reboot required after driver installation
```bash
sudo reboot
```

### CUDA Not Found

**Symptom**: `nvcc: command not found`

**Solution**: Source CUDA environment or restart shell
```bash
source /etc/profile.d/cuda.sh
# OR log out and back in
```

### PyTorch Not Using GPU

**Symptom**: `torch.cuda.is_available()` returns False

**Solution**:
1. Verify driver: `nvidia-smi`
2. Reinstall PyTorch:
```bash
conda activate forge-cuda
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 --force-reinstall
```

### Forge Launch Fails

**Solution**:
1. Activate environment: `conda activate forge-cuda`
2. Verify PyTorch: `python -c "import torch; print(torch.cuda.is_available())"`
3. Check logs in `~/llm/sd-webui-forge/`
4. Try manual launch:
```bash
cd ~/llm/sd-webui-forge
bash webui.sh
```

### "Permission denied" during playbook run

**Solution**: Ensure passwordless sudo or use:
```bash
ansible-playbook main.yml --ask-become-pass
```

## Remote Deployment

To deploy on a remote Ubuntu machine:

1. Edit `inventory.ini`:
```ini
[remote]
your-server-ip ansible_user=your-username

[remote:vars]
ansible_become_password=your-sudo-password
```

2. Run against remote host:
```bash
ansible-playbook -i inventory.ini main.yml -l remote
```

## Advanced Usage

### Shared Model Directory

To use a shared model directory, edit `group_vars/localhost.yml`:

```yaml
shared_models_dir: "/mnt/data/ai-models"
shared_models_types:
  - Stable-diffusion
  - Lora
  - VAE
  - ControlNet
  - ESRGAN
```

### Custom Conda Environment

Modify the conda environment:

```yaml
forge_conda_env: "my-custom-env"
forge_python_version: "3.10.11"
```

### Different NVIDIA Driver

Use a specific driver version:

```yaml
nvidia_driver_version: 560  # Latest driver
```

## Testing in a VM

Test before running on your main system:

```bash
# Using VirtualBox, VMware, etc.
# Create fresh Ubuntu 22.04 VM with GPU passthrough
# Then inside VM:
git clone <repo> forge-neo
cd forge-neo
ansible-playbook main.yml
sudo reboot
```

## Post-Installation Info Files

Check these generated info files in your home directory:

- `~/.nvidia-info` - NVIDIA/CUDA configuration details
- `~/.forge-cuda-info` - Forge installation details
- `~/.ansible-deployment-log` - Deployment summary

## Further Reading

- [Ansible Documentation](https://docs.ansible.com/)
- [NVIDIA CUDA Installation Guide](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
- [Stable Diffusion WebUI Forge](https://github.com/lllyasviel/stable-diffusion-webui-forge)
- [PyTorch CUDA](https://pytorch.org/get-started/locally/)

## License

MIT License - Feel free to use and modify as needed.

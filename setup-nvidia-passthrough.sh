#!/bin/bash
# Setup NVIDIA GPU Passthrough for KVM/QEMU
# This script helps configure VFIO for NVIDIA GPU passthrough to VMs

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "============================================"
echo "NVIDIA GPU Passthrough Setup"
echo "============================================"
echo ""

# Function to print error and exit
error_exit() {
    echo -e "${RED}✗ Error: $1${NC}"
    exit 1
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

echo "=========================================="
echo "Phase 1: Prerequisites Check"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error_exit "This script must be run as root (use sudo)"
fi

# Check for required commands
echo "Checking required tools..."
MISSING_TOOLS=()

for tool in lspci lsmod modprobe update-initramfs; do
    if ! command -v "$tool" &> /dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    error_exit "Missing required tools: ${MISSING_TOOLS[*]}"
fi

print_success "All required tools are installed"
echo ""

echo "=========================================="
echo "Phase 2: IOMMU Verification"
echo "=========================================="
echo ""

# Check if IOMMU is enabled in kernel
if dmesg | grep -q -E "DMAR|IOMMU"; then
    print_success "IOMMU is enabled in kernel"
    echo ""
    echo "IOMMU groups found:"
    dmesg | grep -E "DMAR|IOMMU" | head -5
else
    print_warning "IOMMU may not be enabled"
    echo ""
    echo "To enable IOMMU, add to kernel parameters:"
    echo "  Intel: intel_iommu=on iommu=pt"
    echo "  AMD:   amd_iommu=on iommu=pt"
    echo ""
    echo "Edit /etc/default/grub and add to GRUB_CMDLINE_LINUX_DEFAULT"
    echo "Then run: sudo update-grub && sudo reboot"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo ""

echo "=========================================="
echo "Phase 3: NVIDIA GPU Detection"
echo "=========================================="
echo ""

# Detect NVIDIA GPUs
if ! lspci -nn | grep -qi nvidia; then
    error_exit "No NVIDIA GPU detected. Check that your GPU is installed."
fi

print_success "NVIDIA GPU(s) detected"
echo ""
echo "Available NVIDIA devices:"
lspci -nn | grep -i nvidia | nl
echo ""

# Get NVIDIA device IDs
echo "Extracting NVIDIA device IDs for VFIO..."
GPU_IDS=$(lspci -nn | grep -i nvidia | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}' | paste -sd ',' -)

if [ -z "$GPU_IDS" ]; then
    error_exit "Could not extract GPU device IDs"
fi

print_success "Found device IDs: $GPU_IDS"
echo ""

echo "=========================================="
echo "Phase 4: VFIO Configuration"
echo "=========================================="
echo ""

# Check if VFIO is already bound
if lspci -k | grep -A 3 -i nvidia | grep -q "vfio-pci"; then
    print_success "VFIO is already bound to NVIDIA GPU"
    echo ""
    lspci -k | grep -A 3 -i nvidia
else
    print_warning "VFIO is not yet bound to NVIDIA GPU"
    echo ""
    echo "This script will configure VFIO for your NVIDIA GPU(s)."
    echo ""
    echo "WARNING: This will prevent the host from using the NVIDIA GPU."
    echo "         The GPU will only be available for VM passthrough."
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi

    echo ""
    echo "Configuring VFIO..."

    # Create VFIO module configuration
    echo "Creating /etc/modprobe.d/vfio.conf..."
    cat > /etc/modprobe.d/vfio.conf << EOF
# Bind NVIDIA GPU to VFIO for passthrough
options vfio-pci ids=$GPU_IDS
# Prevent nvidia driver from loading
softdep nvidia pre: vfio-pci
EOF
    print_success "Created VFIO configuration"

    # Create modules load configuration
    echo ""
    echo "Creating /etc/modules-load.d/vfio.conf..."
    cat > /etc/modules-load.d/vfio.conf << EOF
# Load VFIO modules at boot for GPU passthrough
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF
    print_success "Created modules load configuration"

    # Blacklist nvidia drivers
    echo ""
    echo "Creating /etc/modprobe.d/blacklist-nvidia.conf..."
    cat > /etc/modprobe.d/blacklist-nvidia.conf << EOF
# Blacklist NVIDIA drivers to prevent host from using GPU
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nouveau
EOF
    print_success "Created nvidia blacklist"

    echo ""
    echo "Updating initramfs..."
    update-initramfs -u -k all
    print_success "Initramfs updated"

    echo ""
    echo "=========================================="
    echo -e "${GREEN}✓ VFIO Configuration Complete!${NC}"
    echo "=========================================="
    echo ""
    echo -e "${YELLOW}IMPORTANT:${NC}"
    echo "  1. REBOOT is REQUIRED for changes to take effect"
    echo "  2. After reboot, verify VFIO binding:"
    echo "     lspci -k | grep -A 3 -i nvidia"
    echo "  3. You should see 'Kernel driver in use: vfio-pci'"
    echo "  4. Then run: sudo ./fix-vfio-permissions.sh"
    echo ""
    echo "Configuration details:"
    echo "  Device IDs: $GPU_IDS"
    echo "  VFIO config: /etc/modprobe.d/vfio.conf"
    echo "  Modules load: /etc/modules-load.d/vfio.conf"
    echo "  Blacklist: /etc/modprobe.d/blacklist-nvidia.conf"
    echo ""
    read -p "Would you like to reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Rebooting in 5 seconds... (Ctrl+C to cancel)"
        sleep 5
        reboot
    fi
fi

echo ""
echo "=========================================="
echo "Current VFIO Status"
echo "=========================================="
echo ""
echo "NVIDIA devices and drivers:"
lspci -k | grep -A 3 -i nvidia
echo ""
echo "VFIO devices:"
ls -la /dev/vfio/ 2>/dev/null || echo "  (no VFIO devices found)"
echo ""
echo "Next steps:"
echo "  1. Ensure VFIO permissions: sudo ./fix-vfio-permissions.sh"
echo "  2. Configure your VM with GPU passthrough"
echo "  3. Use virsh or virt-manager to attach PCI devices"
echo ""

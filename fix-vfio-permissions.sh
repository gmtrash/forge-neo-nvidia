#!/bin/bash
# Fix VFIO device permissions for GPU passthrough
# This script works for both AMD and NVIDIA GPUs

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "VFIO Device Permissions Setup"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Get the actual user (not root when using sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"

echo "Setting up VFIO permissions for user: $ACTUAL_USER"
echo ""

# Add user to kvm and libvirt groups
echo "Adding $ACTUAL_USER to required groups..."

if groups "$ACTUAL_USER" | grep -q '\bkvm\b'; then
    echo -e "${GREEN}✓ User already in kvm group${NC}"
else
    usermod -aG kvm "$ACTUAL_USER"
    echo -e "${GREEN}✓ Added user to kvm group${NC}"
fi

if groups "$ACTUAL_USER" | grep -q '\blibvirt\b'; then
    echo -e "${GREEN}✓ User already in libvirt group${NC}"
else
    usermod -aG libvirt "$ACTUAL_USER"
    echo -e "${GREEN}✓ Added user to libvirt group${NC}"
fi

echo ""

# Create udev rule for VFIO permissions
echo "Creating udev rule for VFIO devices..."
cat > /etc/udev/rules.d/99-vfio-permissions.rules << 'EOF'
# Grant kvm group access to VFIO devices for GPU passthrough
SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm", MODE="0660"
EOF

echo -e "${GREEN}✓ Created /etc/udev/rules.d/99-vfio-permissions.rules${NC}"
echo ""

# Apply permissions to existing VFIO devices
if [ -d "/dev/vfio" ]; then
    echo "Applying permissions to existing VFIO devices..."
    chown root:kvm /dev/vfio/*
    chmod 660 /dev/vfio/*
    echo -e "${GREEN}✓ Permissions applied${NC}"
else
    echo -e "${YELLOW}⚠ No VFIO devices found yet (this is normal if VFIO isn't configured)${NC}"
fi

echo ""

# Reload udev rules
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger
echo -e "${GREEN}✓ Udev rules reloaded${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}✓ VFIO Permissions Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Current VFIO devices:"
ls -la /dev/vfio/ 2>/dev/null || echo "  (none yet - configure VFIO first)"
echo ""
echo "User groups for $ACTUAL_USER:"
groups "$ACTUAL_USER"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC}"
echo "  1. Log out and back in for group changes to take effect"
echo "  2. Verify groups with: groups"
echo "  3. Then configure VFIO for your GPU (see setup-nvidia-passthrough.sh)"
echo ""

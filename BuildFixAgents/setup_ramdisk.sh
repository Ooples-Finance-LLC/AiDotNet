#!/bin/bash

# RAM Disk Setup Script for BuildFixAgents
# Creates high-performance RAM disk for state files and caching

set -euo pipefail

# Configuration
RAMDISK_SIZE=${RAMDISK_SIZE:-2G}
RAMDISK_PATH="/mnt/buildfix_ramdisk"
STATE_LINK="$HOME/.buildfix_ramdisk_state"
SYSTEMD_SERVICE="/etc/systemd/system/buildfix-ramdisk.service"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running with sufficient privileges
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run with sudo privileges"
        echo "Usage: sudo $0 [setup|remove|status]"
        exit 1
    fi
}

# Check system compatibility
check_system() {
    log_info "Checking system compatibility..."
    
    # Check available memory
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    local required_mem=2
    
    if [[ ${RAMDISK_SIZE%G} -gt 2 ]]; then
        required_mem=${RAMDISK_SIZE%G}
    fi
    
    if [[ $total_mem -lt $((required_mem * 2)) ]]; then
        log_warning "System has ${total_mem}GB RAM. Recommended: $((required_mem * 2))GB+ for ${RAMDISK_SIZE} RAM disk"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check if tmpfs is supported
    if ! grep -q tmpfs /proc/filesystems; then
        log_error "tmpfs not supported on this system"
        exit 1
    fi
    
    log_success "System check passed"
}

# Create RAM disk
create_ramdisk() {
    log_info "Creating RAM disk at $RAMDISK_PATH with size $RAMDISK_SIZE..."
    
    # Create mount point
    if [[ ! -d "$RAMDISK_PATH" ]]; then
        mkdir -p "$RAMDISK_PATH"
        log_success "Created mount point: $RAMDISK_PATH"
    fi
    
    # Check if already mounted
    if mountpoint -q "$RAMDISK_PATH"; then
        log_warning "RAM disk already mounted at $RAMDISK_PATH"
        return 0
    fi
    
    # Mount RAM disk
    if mount -t tmpfs -o size="$RAMDISK_SIZE",mode=1777 tmpfs "$RAMDISK_PATH"; then
        log_success "RAM disk mounted successfully"
    else
        log_error "Failed to mount RAM disk"
        exit 1
    fi
    
    # Create directory structure
    mkdir -p "$RAMDISK_PATH/state"
    mkdir -p "$RAMDISK_PATH/cache"
    mkdir -p "$RAMDISK_PATH/chunks"
    mkdir -p "$RAMDISK_PATH/logs"
    mkdir -p "$RAMDISK_PATH/metrics"
    
    # Set permissions
    chmod 777 "$RAMDISK_PATH"/*
    
    log_success "RAM disk structure created"
}

# Create symbolic links
create_symlinks() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local original_user="${SUDO_USER:-$USER}"
    
    log_info "Creating symbolic links for BuildFixAgents state..."
    
    # Backup existing state directory if it exists
    if [[ -d "$script_dir/state" ]] && [[ ! -L "$script_dir/state" ]]; then
        log_info "Backing up existing state directory..."
        mv "$script_dir/state" "$script_dir/state.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Create symbolic link
    if [[ -L "$script_dir/state" ]]; then
        rm -f "$script_dir/state"
    fi
    ln -s "$RAMDISK_PATH/state" "$script_dir/state"
    chown -h "$original_user:$original_user" "$script_dir/state"
    
    # Create user convenience link
    if [[ -L "$STATE_LINK" ]]; then
        rm -f "$STATE_LINK"
    fi
    sudo -u "$original_user" ln -s "$RAMDISK_PATH" "$STATE_LINK"
    
    log_success "Symbolic links created"
}

# Create systemd service for persistence
create_systemd_service() {
    log_info "Creating systemd service for automatic RAM disk setup..."
    
    cat > "$SYSTEMD_SERVICE" << EOF
[Unit]
Description=BuildFix RAM Disk
Before=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'mkdir -p $RAMDISK_PATH && mount -t tmpfs -o size=$RAMDISK_SIZE,mode=1777 tmpfs $RAMDISK_PATH && mkdir -p $RAMDISK_PATH/{state,cache,chunks,logs,metrics} && chmod 777 $RAMDISK_PATH/*'
ExecStop=/bin/umount $RAMDISK_PATH
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable service
    systemctl daemon-reload
    systemctl enable buildfix-ramdisk.service
    
    log_success "Systemd service created and enabled"
}

# Add to fstab for persistence
add_to_fstab() {
    log_info "Adding RAM disk to /etc/fstab..."
    
    # Check if already in fstab
    if grep -q "$RAMDISK_PATH" /etc/fstab; then
        log_warning "RAM disk already in /etc/fstab"
        return 0
    fi
    
    # Backup fstab
    cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
    
    # Add entry
    echo "# BuildFix RAM disk" >> /etc/fstab
    echo "tmpfs $RAMDISK_PATH tmpfs size=$RAMDISK_SIZE,mode=1777 0 0" >> /etc/fstab
    
    log_success "Added to /etc/fstab"
}

# Setup environment variables
setup_environment() {
    local original_user="${SUDO_USER:-$USER}"
    local shell_rc=""
    
    # Determine shell RC file
    if [[ -f "/home/$original_user/.bashrc" ]]; then
        shell_rc="/home/$original_user/.bashrc"
    elif [[ -f "/home/$original_user/.zshrc" ]]; then
        shell_rc="/home/$original_user/.zshrc"
    fi
    
    if [[ -n "$shell_rc" ]]; then
        log_info "Setting up environment variables in $shell_rc..."
        
        # Remove old entries
        sudo -u "$original_user" sed -i '/# BuildFix RAM disk configuration/,/# End BuildFix RAM disk/d' "$shell_rc"
        
        # Add new entries
        cat >> "$shell_rc" << EOF

# BuildFix RAM disk configuration
export BUILDFIX_STATE_DIR="$RAMDISK_PATH/state"
export BUILDFIX_CACHE_DIR="$RAMDISK_PATH/cache"
export BUILDFIX_USE_RAMDISK=true
# End BuildFix RAM disk
EOF
        
        log_success "Environment variables configured"
        log_info "Run 'source $shell_rc' to apply changes to current session"
    fi
}

# Remove RAM disk
remove_ramdisk() {
    log_info "Removing RAM disk setup..."
    
    # Unmount if mounted
    if mountpoint -q "$RAMDISK_PATH"; then
        log_info "Unmounting RAM disk..."
        if umount "$RAMDISK_PATH"; then
            log_success "RAM disk unmounted"
        else
            log_error "Failed to unmount RAM disk. It may be in use."
            return 1
        fi
    fi
    
    # Remove directory
    if [[ -d "$RAMDISK_PATH" ]]; then
        rmdir "$RAMDISK_PATH" 2>/dev/null || log_warning "Could not remove $RAMDISK_PATH"
    fi
    
    # Remove from fstab
    if grep -q "$RAMDISK_PATH" /etc/fstab; then
        log_info "Removing from /etc/fstab..."
        sed -i.backup "\\|$RAMDISK_PATH|d" /etc/fstab
        sed -i '/# BuildFix RAM disk/d' /etc/fstab
    fi
    
    # Remove systemd service
    if [[ -f "$SYSTEMD_SERVICE" ]]; then
        log_info "Removing systemd service..."
        systemctl disable buildfix-ramdisk.service 2>/dev/null || true
        rm -f "$SYSTEMD_SERVICE"
        systemctl daemon-reload
    fi
    
    # Remove symbolic links
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -L "$script_dir/state" ]]; then
        rm -f "$script_dir/state"
    fi
    if [[ -L "$STATE_LINK" ]]; then
        rm -f "$STATE_LINK"
    fi
    
    log_success "RAM disk setup removed"
}

# Show status
show_status() {
    echo -e "${CYAN}BuildFix RAM Disk Status${NC}"
    echo -e "${CYAN}========================${NC}"
    
    # Check if mounted
    if mountpoint -q "$RAMDISK_PATH" 2>/dev/null; then
        echo -e "Status: ${GREEN}Mounted${NC}"
        
        # Show usage
        df -h "$RAMDISK_PATH" | tail -1 | awk '{
            printf "Size: %s\n", $2
            printf "Used: %s (%s)\n", $3, $5
            printf "Available: %s\n", $4
        }'
        
        # Show contents
        echo -e "\nContents:"
        du -sh "$RAMDISK_PATH"/* 2>/dev/null | sort -h
        
        # Show performance
        echo -e "\nPerformance Test:"
        dd if=/dev/zero of="$RAMDISK_PATH/test" bs=1M count=100 2>&1 | grep -E 'copied|MB/s'
        rm -f "$RAMDISK_PATH/test"
    else
        echo -e "Status: ${RED}Not Mounted${NC}"
    fi
    
    # Check systemd service
    echo -e "\nSystemd Service:"
    if systemctl is-enabled buildfix-ramdisk.service &>/dev/null; then
        echo -e "Enabled: ${GREEN}Yes${NC}"
    else
        echo -e "Enabled: ${RED}No${NC}"
    fi
    
    # Check fstab
    echo -e "\nPersistence:"
    if grep -q "$RAMDISK_PATH" /etc/fstab 2>/dev/null; then
        echo -e "In fstab: ${GREEN}Yes${NC}"
    else
        echo -e "In fstab: ${RED}No${NC}"
    fi
}

# Main setup function
setup() {
    check_system
    create_ramdisk
    create_symlinks
    create_systemd_service
    add_to_fstab
    setup_environment
    
    echo
    log_success "RAM disk setup complete!"
    echo
    echo -e "${CYAN}Quick Start:${NC}"
    echo "1. Source your shell RC file to update environment:"
    echo "   source ~/.bashrc  # or ~/.zshrc"
    echo
    echo "2. Verify setup:"
    echo "   $0 status"
    echo
    echo "3. The BuildFixAgents state directory now uses RAM disk for maximum performance!"
    echo
    echo -e "${YELLOW}Note:${NC} RAM disk contents are lost on reboot. Important data should be backed up."
}

# Main function
main() {
    case "${1:-setup}" in
        setup)
            check_privileges
            setup
            ;;
        remove)
            check_privileges
            remove_ramdisk
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 [setup|remove|status]"
            echo
            echo "Commands:"
            echo "  setup   - Create and configure RAM disk (default)"
            echo "  remove  - Remove RAM disk and configuration"
            echo "  status  - Show current RAM disk status"
            echo
            echo "Options:"
            echo "  RAMDISK_SIZE=4G $0 setup  # Set custom size (default: 2G)"
            exit 1
            ;;
    esac
}

# Run main
main "$@"
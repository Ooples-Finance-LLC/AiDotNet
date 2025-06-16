#!/bin/bash

# Deployment script for Multi-Agent Build Fix System
# Creates a portable package that can be used in any C# project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_NAME="BuildFixAgents"
VERSION="2.0.0"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Create deployment package
create_package() {
    local target="${1:-$SCRIPT_DIR/${DEPLOY_NAME}_${VERSION}.tar.gz}"
    
    print_message "$BLUE" "Creating deployment package..."
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    local package_dir="$temp_dir/$DEPLOY_NAME"
    
    # Copy essential files
    mkdir -p "$package_dir"
    cp "$SCRIPT_DIR"/*.sh "$package_dir/"
    cp "$SCRIPT_DIR"/*.md "$package_dir/"
    
    # Create empty directories
    mkdir -p "$package_dir/logs"
    mkdir -p "$package_dir/state"
    
    # Create .gitignore for the package
    cat > "$package_dir/.gitignore" << EOF
logs/
state/
.lock_*
.pid_*
*.log
build_output.txt
EOF
    
    # Make scripts executable
    chmod +x "$package_dir"/*.sh
    
    # Create archive
    cd "$temp_dir"
    tar -czf "$target" "$DEPLOY_NAME"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    print_message "$GREEN" "✓ Package created: $target"
    print_message "$YELLOW" "  Size: $(du -h "$target" | cut -f1)"
    
    # Show deployment instructions
    print_message "$BLUE" "
Deployment Instructions:
1. Copy $target to your C# project
2. Extract: tar -xzf $(basename "$target")
3. Run: ./BuildFixAgents/run_build_fix.sh analyze
4. Fix: ./BuildFixAgents/run_build_fix.sh fix
"
}

# Install to a target project
install_to_project() {
    local target_dir="${1:-}"
    
    if [[ -z "$target_dir" ]]; then
        print_message "$YELLOW" "Usage: $0 install <target-project-directory>"
        exit 1
    fi
    
    if [[ ! -d "$target_dir" ]]; then
        print_message "$YELLOW" "Error: Directory $target_dir does not exist"
        exit 1
    fi
    
    print_message "$BLUE" "Installing to: $target_dir"
    
    # Check if it's a C# project
    if ! find "$target_dir" -name "*.csproj" -maxdepth 3 | grep -q .; then
        print_message "$YELLOW" "Warning: No .csproj file found. Is this a C# project?"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Copy the system
    cp -r "$SCRIPT_DIR" "$target_dir/$DEPLOY_NAME"
    
    # Clean up any existing state
    rm -rf "$target_dir/$DEPLOY_NAME/logs"/*
    rm -rf "$target_dir/$DEPLOY_NAME/state"/*
    rm -f "$target_dir/$DEPLOY_NAME"/.lock_*
    rm -f "$target_dir/$DEPLOY_NAME"/.pid_*
    
    print_message "$GREEN" "✓ Installation complete!"
    print_message "$BLUE" "
To use the system:
cd $target_dir
./$DEPLOY_NAME/run_build_fix.sh analyze
./$DEPLOY_NAME/run_build_fix.sh fix
"
}

# Main menu
case "${1:-help}" in
    "package")
        create_package "${2:-}"
        ;;
    "install")
        install_to_project "${2:-}"
        ;;
    *)
        print_message "$BLUE" "
Multi-Agent Build Fix System Deployment Tool

Usage:
  $0 package [output.tar.gz]  - Create deployment package
  $0 install <project-dir>    - Install to a C# project

Examples:
  $0 package                           # Create package with default name
  $0 package ~/Desktop/buildfix.tar.gz # Create package with custom name
  $0 install /path/to/my/project       # Install directly to a project
"
        ;;
esac
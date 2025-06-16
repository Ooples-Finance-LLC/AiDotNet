#!/bin/bash

# Safe Fix Wrapper with Automatic Rollback
# Monitors changes and rolls back if errors increase

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
BACKUP_DIR="$AGENT_DIR/backups/$(date +%Y%m%d_%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create backup of current state
create_backup() {
    echo -e "${YELLOW}Creating backup...${NC}"
    mkdir -p "$BACKUP_DIR"
    
    # Get list of tracked files
    cd "$PROJECT_DIR"
    git ls-files "*.cs" > "$BACKUP_DIR/file_list.txt"
    
    # Backup each file
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$file")"
            cp "$file" "$BACKUP_DIR/$file"
        fi
    done < "$BACKUP_DIR/file_list.txt"
    
    # Save current error state
    dotnet build > "$BACKUP_DIR/build_output_before.txt" 2>&1 || true
    local error_count=$(grep -c 'error CS' "$BACKUP_DIR/build_output_before.txt" || echo "0")
    echo "$error_count" > "$BACKUP_DIR/error_count_before.txt"
    
    echo -e "${GREEN}Backup created: $BACKUP_DIR${NC}"
    return $error_count
}

# Restore from backup
restore_backup() {
    echo -e "${RED}Restoring from backup...${NC}"
    
    if [[ ! -f "$BACKUP_DIR/file_list.txt" ]]; then
        echo -e "${RED}No backup found!${NC}"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    while IFS= read -r file; do
        if [[ -f "$BACKUP_DIR/$file" ]]; then
            cp "$BACKUP_DIR/$file" "$file"
        fi
    done < "$BACKUP_DIR/file_list.txt"
    
    echo -e "${GREEN}Files restored from backup${NC}"
}

# Monitor fix process
monitor_with_safety() {
    local initial_errors=$1
    local safety_threshold=$((initial_errors + 5))  # Allow max 5 more errors
    
    # Run the autofix
    bash "$AGENT_DIR/autofix.sh" once &
    local fix_pid=$!
    
    # Monitor for safety
    while ps -p $fix_pid > /dev/null 2>&1; do
        sleep 10
        
        # Check current error count
        if dotnet build > "$AGENT_DIR/logs/build_output_current.txt" 2>&1; then
            # Build succeeded
            continue
        else
            local current_errors=$(grep -c 'error CS' "$AGENT_DIR/logs/build_output_current.txt" || echo "0")
            
            if [[ $current_errors -gt $safety_threshold ]]; then
                echo -e "${RED}ERROR: Error count increased beyond safety threshold!${NC}"
                echo -e "${RED}Initial: $initial_errors, Current: $current_errors, Threshold: $safety_threshold${NC}"
                
                # Kill the fix process
                kill $fix_pid 2>/dev/null || true
                
                # Restore backup
                restore_backup
                
                return 1
            fi
        fi
    done
    
    wait $fix_pid
    return $?
}

# Verify fix results
verify_results() {
    cd "$PROJECT_DIR"
    
    echo -e "${YELLOW}Verifying results...${NC}"
    
    if dotnet build > "$AGENT_DIR/logs/build_output_after.txt" 2>&1; then
        echo -e "${GREEN}✓ Build successful!${NC}"
        
        # Clean up backup
        echo -e "${YELLOW}Cleaning up backup...${NC}"
        rm -rf "$BACKUP_DIR"
        
        return 0
    else
        local final_errors=$(grep -c 'error CS' "$AGENT_DIR/logs/build_output_after.txt" || echo "0")
        local initial_errors=$(cat "$BACKUP_DIR/error_count_before.txt")
        
        if [[ $final_errors -lt $initial_errors ]]; then
            echo -e "${GREEN}✓ Reduced errors from $initial_errors to $final_errors${NC}"
            
            # Keep backup for safety
            echo -e "${YELLOW}Backup kept at: $BACKUP_DIR${NC}"
            
            return 0
        else
            echo -e "${RED}✗ No improvement achieved${NC}"
            return 1
        fi
    fi
}

# Main execution
main() {
    echo -e "${YELLOW}═══ Safe Fix Mode ═══${NC}"
    
    # Create backup and get initial error count
    create_backup
    local initial_errors=$?
    
    if [[ $initial_errors -eq 0 ]]; then
        echo -e "${GREEN}No errors found - build is already clean!${NC}"
        rm -rf "$BACKUP_DIR"
        exit 0
    fi
    
    echo -e "${YELLOW}Found $initial_errors errors to fix${NC}"
    
    # Run fix with monitoring
    if monitor_with_safety $initial_errors; then
        verify_results
    else
        echo -e "${RED}Fix process failed or was stopped for safety${NC}"
        exit 1
    fi
}

# Handle arguments
case "${1:-run}" in
    "run")
        main
        ;;
    "restore")
        BACKUP_DIR="${2:-$(ls -dt $AGENT_DIR/backups/* | head -1)}"
        restore_backup
        ;;
    *)
        echo "Usage: $0 {run|restore [backup_dir]}"
        ;;
esac
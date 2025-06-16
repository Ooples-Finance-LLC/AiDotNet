#!/bin/bash

# File Modification Library for BuildFixAgents
# Safe file modification with rollback support

# Backup directory
BACKUP_DIR="${BACKUP_DIR:-/tmp/buildfix_backups}"
mkdir -p "$BACKUP_DIR"

# Apply a pattern-based fix to a file
apply_pattern_fix() {
    local file="$1"
    local error_type="$2"
    local pattern="$3"
    local replacement="$4"
    local line_number="${5:-}"
    
    # Validate inputs
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        return 1
    fi
    
    # Create backup
    local backup_file="$BACKUP_DIR/$(basename "$file").$(date +%s).backup"
    cp "$file" "$backup_file"
    echo "Backup created: $backup_file" >&2
    
    # Apply fix based on type
    case "$error_type" in
        "CS0101") # Duplicate class definition
            # Remove duplicate class definition
            apply_cs0101_fix "$file" "$pattern"
            ;;
        "CS0111") # Duplicate method
            # Remove duplicate method
            apply_cs0111_fix "$file" "$pattern" "$line_number"
            ;;
        "CS0462") # Inheritance conflict
            # Fix inheritance issue
            apply_cs0462_fix "$file" "$pattern" "$replacement"
            ;;
        *)
            # Generic pattern replacement
            sed -i "s|$pattern|$replacement|g" "$file"
            ;;
    esac
    
    # Verify the fix
    if verify_fix "$file" "$backup_file"; then
        echo "SUCCESS: Fix applied to $file" >&2
        return 0
    else
        # Rollback on failure
        mv "$backup_file" "$file"
        echo "ROLLBACK: Fix failed, restored original" >&2
        return 1
    fi
}

# Fix CS0101 - Duplicate class/type definition
apply_cs0101_fix() {
    local file="$1"
    local duplicate_name="$2"
    
    # Find duplicate definitions
    local occurrences=$(grep -n "class $duplicate_name\|struct $duplicate_name\|enum $duplicate_name" "$file" | wc -l)
    
    if [[ $occurrences -gt 1 ]]; then
        # Remove the second occurrence
        # This is a simplified approach - in production would need more logic
        local first_line=$(grep -n "class $duplicate_name\|struct $duplicate_name\|enum $duplicate_name" "$file" | head -1 | cut -d: -f1)
        local second_line=$(grep -n "class $duplicate_name\|struct $duplicate_name\|enum $duplicate_name" "$file" | sed -n '2p' | cut -d: -f1)
        
        if [[ -n "$second_line" ]]; then
            # Find the end of the duplicate class
            local end_line=$(awk "NR>$second_line && /^}/ {print NR; exit}" "$file")
            if [[ -n "$end_line" ]]; then
                sed -i "${second_line},${end_line}d" "$file"
            fi
        fi
    fi
}

# Fix CS0111 - Duplicate method
apply_cs0111_fix() {
    local file="$1"
    local method_name="$2"
    local line_to_remove="$3"
    
    if [[ -n "$line_to_remove" ]]; then
        # Remove specific method by line number
        # Find method end (next method or class end)
        local method_end=$(awk "NR>$line_to_remove && /^[[:space:]]*}[[:space:]]*$/ {print NR; exit}" "$file")
        if [[ -n "$method_end" ]]; then
            sed -i "${line_to_remove},${method_end}d" "$file"
        fi
    else
        # Remove duplicate by pattern matching
        # Count occurrences
        local count=$(grep -c "$method_name" "$file" || true)
        if [[ $count -gt 1 ]]; then
            # Remove the last occurrence
            tac "$file" | awk "/$method_name/ && !found {found=1; next} 1" | tac > "$file.tmp"
            mv "$file.tmp" "$file"
        fi
    fi
}

# Fix CS0462 - Override conflicts
apply_cs0462_fix() {
    local file="$1"
    local method_signature="$2"
    local correct_override="$3"
    
    # Replace the conflicting override
    sed -i "s|$method_signature|$correct_override|g" "$file"
}

# Verify the fix compiles
verify_fix() {
    local file="$1"
    local backup="$2"
    
    # Get the project directory
    local project_dir=$(dirname "$file")
    while [[ ! -f "$project_dir"/*.csproj ]] && [[ "$project_dir" != "/" ]]; do
        project_dir=$(dirname "$project_dir")
    done
    
    # Try to compile
    if cd "$project_dir" && timeout 30s dotnet build --no-restore >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Export functions for use by other scripts
export -f apply_pattern_fix apply_cs0101_fix apply_cs0111_fix apply_cs0462_fix verify_fix

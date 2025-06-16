#!/bin/bash

# State Validation System
# Ensures state files are valid and consistent

# Validate JSON state file
validate_json_state() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Check if valid JSON
    if ! jq . "$file" >/dev/null 2>&1; then
        echo "Invalid JSON in $file" >&2
        return 1
    fi
    
    return 0
}

# Validate state directory structure
validate_state_structure() {
    local required_dirs=(
        "$STATE_DIR"
        "$STATE_DIR/architecture"
        "$STATE_DIR/logs"
    )
    
    local missing=0
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo "Missing state directory: $dir" >&2
            mkdir -p "$dir"
            ((missing++))
        fi
    done
    
    return $missing
}

# Clean stale state files
clean_stale_state() {
    local max_age="${1:-1440}"  # 24 hours in minutes
    
    echo "Cleaning state files older than $max_age minutes..."
    
    # Find and remove old cache files
    find "$STATE_DIR" -name "*.cache" -mmin +$max_age -delete 2>/dev/null
    find "$STATE_DIR" -name "*.tmp" -mmin +60 -delete 2>/dev/null
    find "$STATE_DIR" -name "*.lock" -mmin +5 -delete 2>/dev/null
    
    # Clean old build outputs
    find "$STATE_DIR" -name "build_output_*.txt" -mmin +$max_age -delete 2>/dev/null
}

# Repair corrupted state
repair_state() {
    echo "Repairing state files..."
    
    # Fix corrupted JSON files
    for json_file in "$STATE_DIR"/**/*.json; do
        if [[ -f "$json_file" ]] && ! validate_json_state "$json_file"; then
            echo "Repairing $json_file"
            # Backup corrupted file
            mv "$json_file" "${json_file}.corrupted.$(date +%s)"
            # Create empty valid JSON
            echo '{}' > "$json_file"
        fi
    done
    
    # Ensure required files exist
    [[ ! -f "$STATE_DIR/detected_language.txt" ]] && echo "csharp" > "$STATE_DIR/detected_language.txt"
    [[ ! -f "$STATE_DIR/.gitignore" ]] && echo -e "*.cache\n*.tmp\n*.lock" > "$STATE_DIR/.gitignore"
}

export -f validate_json_state validate_state_structure clean_stale_state repair_state

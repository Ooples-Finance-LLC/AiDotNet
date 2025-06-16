#!/bin/bash

# Knowledge Management System for Build Fix Agents
# Captures, organizes, and retrieves organizational knowledge for improved problem-solving

set -euo pipefail

# Configuration
KNOWLEDGE_DIR="${BUILD_FIX_HOME:-$HOME/.buildfix}/knowledge"
KNOWLEDGE_BASE="$KNOWLEDGE_DIR/base"
SOLUTIONS_DB="$KNOWLEDGE_DIR/solutions"
PATTERNS_DB="$KNOWLEDGE_DIR/patterns"
LESSONS_DB="$KNOWLEDGE_DIR/lessons"
INDEX_DIR="$KNOWLEDGE_DIR/index"
EMBEDDINGS_DIR="$KNOWLEDGE_DIR/embeddings"
CONFIG_FILE="$KNOWLEDGE_DIR/config.json"

# Knowledge categories
declare -A CATEGORIES=(
    ["build_errors"]="Build and compilation errors"
    ["runtime_errors"]="Runtime exceptions and crashes"
    ["performance"]="Performance issues and optimizations"
    ["security"]="Security vulnerabilities and fixes"
    ["architecture"]="Architecture patterns and decisions"
    ["best_practices"]="Coding standards and best practices"
    ["tools"]="Tool configurations and usage"
    ["dependencies"]="Dependency management issues"
)

# Initialize knowledge management system
init_knowledge_system() {
    mkdir -p "$KNOWLEDGE_BASE" "$SOLUTIONS_DB" "$PATTERNS_DB" "$LESSONS_DB" "$INDEX_DIR" "$EMBEDDINGS_DIR"
    
    # Create configuration
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" <<EOF
{
    "version": "1.0.0",
    "indexing": {
        "enabled": true,
        "update_frequency": 3600,
        "max_index_size": 1073741824,
        "similarity_threshold": 0.8
    },
    "knowledge_retention": {
        "max_age_days": 365,
        "archive_old_entries": true,
        "compression_enabled": true
    },
    "ai_features": {
        "embeddings_enabled": true,
        "auto_categorization": true,
        "pattern_recognition": true,
        "solution_ranking": true
    },
    "sharing": {
        "export_enabled": true,
        "import_enabled": true,
        "federation_enabled": false
    }
}
EOF
    fi
    
    # Initialize category directories
    for category in "${!CATEGORIES[@]}"; do
        mkdir -p "$KNOWLEDGE_BASE/$category"
        mkdir -p "$SOLUTIONS_DB/$category"
        mkdir -p "$PATTERNS_DB/$category"
    done
    
    # Create initial index
    create_knowledge_index
    
    echo "Knowledge management system initialized at $KNOWLEDGE_DIR"
}

# Capture new knowledge entry
capture_knowledge() {
    local title="$1"
    local category="${2:-general}"
    local content="${3:-}"
    local tags="${4:-}"
    
    # Generate unique ID
    local entry_id=$(generate_entry_id)
    local timestamp=$(date -Iseconds)
    
    # Determine entry type
    local entry_type="knowledge"
    [[ "$content" =~ "error:" ]] && entry_type="error"
    [[ "$content" =~ "solution:" ]] && entry_type="solution"
    [[ "$content" =~ "pattern:" ]] && entry_type="pattern"
    
    # Create knowledge entry
    local entry_dir="$KNOWLEDGE_BASE/$category/$entry_id"
    mkdir -p "$entry_dir"
    
    # Save metadata
    cat > "$entry_dir/metadata.json" <<EOF
{
    "id": "$entry_id",
    "title": "$title",
    "category": "$category",
    "type": "$entry_type",
    "tags": [$(echo "$tags" | sed 's/,/","/g' | sed 's/^/"/;s/$/"/')]",
    "created_at": "$timestamp",
    "updated_at": "$timestamp",
    "author": "$USER",
    "version": 1,
    "references": [],
    "related_entries": [],
    "usage_count": 0,
    "effectiveness_score": 0.0
}
EOF
    
    # Save content
    if [[ -n "$content" ]]; then
        echo "$content" > "$entry_dir/content.md"
    else
        # Open editor for content
        ${EDITOR:-nano} "$entry_dir/content.md"
    fi
    
    # Generate embeddings if enabled
    if [[ $(jq -r '.ai_features.embeddings_enabled' "$CONFIG_FILE") == "true" ]]; then
        generate_embeddings "$entry_id" "$entry_dir/content.md"
    fi
    
    # Update index
    index_entry "$entry_id" "$category"
    
    echo "Knowledge entry captured: $entry_id"
    echo "Title: $title"
    echo "Category: $category"
}

# Record a solution
record_solution() {
    local problem="$1"
    local solution="$2"
    local category="${3:-general}"
    local effectiveness="${4:-pending}"
    
    local solution_id=$(generate_entry_id)
    local timestamp=$(date -Iseconds)
    
    # Create solution entry
    local solution_dir="$SOLUTIONS_DB/$category/$solution_id"
    mkdir -p "$solution_dir"
    
    # Save solution metadata
    cat > "$solution_dir/metadata.json" <<EOF
{
    "id": "$solution_id",
    "problem": "$problem",
    "category": "$category",
    "created_at": "$timestamp",
    "author": "$USER",
    "effectiveness": "$effectiveness",
    "usage_count": 0,
    "success_rate": 0.0,
    "average_time_saved": 0,
    "prerequisites": [],
    "side_effects": [],
    "applicable_contexts": []
}
EOF
    
    # Save solution steps
    cat > "$solution_dir/solution.md" <<EOF
# Problem
$problem

# Solution
$solution

## Steps
1. [Add detailed steps here]

## Verification
- [ ] Problem resolved
- [ ] No side effects
- [ ] Performance acceptable

## Notes
[Add any additional notes or warnings]
EOF
    
    # Open editor for detailed solution
    ${EDITOR:-nano} "$solution_dir/solution.md"
    
    # Link to knowledge base
    link_solution_to_knowledge "$solution_id" "$category"
    
    echo "Solution recorded: $solution_id"
}

# Identify patterns
identify_pattern() {
    local pattern_name="$1"
    local description="$2"
    local category="${3:-general}"
    
    local pattern_id=$(generate_entry_id)
    local timestamp=$(date -Iseconds)
    
    # Create pattern entry
    local pattern_dir="$PATTERNS_DB/$category/$pattern_id"
    mkdir -p "$pattern_dir"
    
    # Save pattern metadata
    cat > "$pattern_dir/metadata.json" <<EOF
{
    "id": "$pattern_id",
    "name": "$pattern_name",
    "category": "$category",
    "description": "$description",
    "created_at": "$timestamp",
    "author": "$USER",
    "occurrences": 1,
    "reliability": 0.0,
    "contexts": [],
    "variations": [],
    "related_patterns": []
}
EOF
    
    # Create pattern template
    cat > "$pattern_dir/pattern.md" <<EOF
# Pattern: $pattern_name

## Description
$description

## Context
[When does this pattern occur?]

## Problem
[What problem does this pattern address?]

## Solution
[How to handle this pattern]

## Examples
\`\`\`
[Add code examples]
\`\`\`

## Consequences
- Positive:
- Negative:

## Related Patterns
- [List related patterns]
EOF
    
    # Open editor for pattern details
    ${EDITOR:-nano} "$pattern_dir/pattern.md"
    
    echo "Pattern identified: $pattern_id ($pattern_name)"
}

# Search knowledge base
search_knowledge() {
    local query="$1"
    local category="${2:-all}"
    local limit="${3:-10}"
    
    echo "Searching knowledge base for: $query"
    echo
    
    # Search in different locations based on query type
    local results=()
    
    # Full-text search
    if command -v rg >/dev/null 2>&1; then
        # Use ripgrep for fast searching
        if [[ "$category" == "all" ]]; then
            mapfile -t results < <(rg -l -i "$query" "$KNOWLEDGE_BASE" "$SOLUTIONS_DB" "$PATTERNS_DB" 2>/dev/null | head -n "$limit")
        else
            mapfile -t results < <(rg -l -i "$query" "$KNOWLEDGE_BASE/$category" "$SOLUTIONS_DB/$category" "$PATTERNS_DB/$category" 2>/dev/null | head -n "$limit")
        fi
    else
        # Fallback to grep
        if [[ "$category" == "all" ]]; then
            mapfile -t results < <(grep -r -l -i "$query" "$KNOWLEDGE_BASE" "$SOLUTIONS_DB" "$PATTERNS_DB" 2>/dev/null | head -n "$limit")
        else
            mapfile -t results < <(grep -r -l -i "$query" "$KNOWLEDGE_BASE/$category" "$SOLUTIONS_DB/$category" "$PATTERNS_DB/$category" 2>/dev/null | head -n "$limit")
        fi
    fi
    
    # Display results
    if [[ ${#results[@]} -eq 0 ]]; then
        echo "No results found."
        
        # Suggest similar entries using embeddings
        if [[ $(jq -r '.ai_features.embeddings_enabled' "$CONFIG_FILE") == "true" ]]; then
            echo
            echo "Searching for similar entries..."
            find_similar_entries "$query" "$limit"
        fi
    else
        echo "Found ${#results[@]} results:"
        echo
        
        for result in "${results[@]}"; do
            display_knowledge_entry "$result"
        done
    fi
}

# Display knowledge entry
display_knowledge_entry() {
    local file_path="$1"
    
    # Determine entry type and extract metadata
    local dir_path=$(dirname "$file_path")
    local metadata_file="$dir_path/metadata.json"
    
    if [[ -f "$metadata_file" ]]; then
        local id=$(jq -r '.id' "$metadata_file")
        local title=$(jq -r '.title // .name // .problem' "$metadata_file")
        local category=$(jq -r '.category' "$metadata_file")
        local type=$(jq -r '.type // "unknown"' "$metadata_file")
        local created=$(jq -r '.created_at' "$metadata_file")
        
        echo "----------------------------------------"
        echo "ID: $id"
        echo "Title: $title"
        echo "Category: $category"
        echo "Type: $type"
        echo "Created: $created"
        echo
        
        # Display content preview
        if [[ -f "$dir_path/content.md" ]]; then
            head -n 5 "$dir_path/content.md"
        elif [[ -f "$dir_path/solution.md" ]]; then
            head -n 5 "$dir_path/solution.md"
        elif [[ -f "$dir_path/pattern.md" ]]; then
            head -n 5 "$dir_path/pattern.md"
        fi
        
        echo "..."
        echo
    fi
}

# Learn from build history
learn_from_history() {
    local project_dir="${1:-.}"
    local history_file="${2:-build_history.log}"
    
    echo "Analyzing build history for patterns and lessons..."
    
    # Extract build errors and their fixes
    local errors_found=0
    local solutions_found=0
    
    if [[ -f "$history_file" ]]; then
        # Parse build logs for errors and resolutions
        while IFS= read -r line; do
            if [[ "$line" =~ "error:" ]] || [[ "$line" =~ "Error:" ]]; then
                ((errors_found++))
                
                # Extract error context
                local error_context=$(echo "$line" | head -c 200)
                
                # Check if we've seen this error before
                if ! search_knowledge "$error_context" "build_errors" 1 | grep -q "Found"; then
                    # New error - capture it
                    capture_knowledge "Build Error: $error_context" "build_errors" "$line" "auto-captured,build-error"
                fi
            fi
            
            if [[ "$line" =~ "fixed:" ]] || [[ "$line" =~ "resolved:" ]]; then
                ((solutions_found++))
                # Extract solution context
                # [Implementation for solution extraction]
            fi
        done < "$history_file"
    fi
    
    # Analyze git history for fix patterns
    if [[ -d ".git" ]]; then
        echo "Analyzing git commits for fix patterns..."
        
        # Look for fix commits
        git log --grep="fix\|Fix\|FIX" --oneline -n 100 | while read -r commit; do
            local commit_hash=$(echo "$commit" | awk '{print $1}')
            local commit_msg=$(echo "$commit" | cut -d' ' -f2-)
            
            # Analyze what was fixed
            local files_changed=$(git diff-tree --no-commit-id --name-only -r "$commit_hash")
            
            # Create pattern entry for common fixes
            if [[ "$commit_msg" =~ "build" ]]; then
                echo "Found build fix pattern: $commit_msg"
                # [Record pattern]
            fi
        done
    fi
    
    echo "Analysis complete:"
    echo "  Errors found: $errors_found"
    echo "  Solutions found: $solutions_found"
    echo "  New patterns identified: [count]"
}

# Generate embeddings for semantic search
generate_embeddings() {
    local entry_id="$1"
    local content_file="$2"
    
    # This is a placeholder for actual embedding generation
    # In production, you would use a language model or embedding service
    
    # For now, create a simple word frequency vector
    local embedding_file="$EMBEDDINGS_DIR/${entry_id}.json"
    
    # Extract keywords and create simple embedding
    local keywords=$(tr -cs '[:alnum:]' '\n' < "$content_file" | \
                    tr '[:upper:]' '[:lower:]' | \
                    sort | uniq -c | sort -nr | \
                    head -20 | awk '{print $2}')
    
    # Save embedding
    echo '{"keywords": [' > "$embedding_file"
    echo "$keywords" | sed 's/^/"/;s/$/",/' | sed '$ s/,$//' >> "$embedding_file"
    echo ']}' >> "$embedding_file"
}

# Find similar entries using embeddings
find_similar_entries() {
    local query="$1"
    local limit="${2:-5}"
    
    # Extract query keywords
    local query_keywords=$(echo "$query" | tr -cs '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | sort -u)
    
    # Calculate similarity scores
    local scores=()
    
    for embedding_file in "$EMBEDDINGS_DIR"/*.json; do
        [[ -f "$embedding_file" ]] || continue
        
        local entry_id=$(basename "$embedding_file" .json)
        local keywords=$(jq -r '.keywords[]' "$embedding_file" 2>/dev/null)
        
        # Simple keyword overlap similarity
        local overlap=0
        while IFS= read -r qkeyword; do
            if echo "$keywords" | grep -q "^$qkeyword$"; then
                ((overlap++))
            fi
        done <<< "$query_keywords"
        
        if [[ $overlap -gt 0 ]]; then
            scores+=("$overlap:$entry_id")
        fi
    done
    
    # Sort by score and display top results
    if [[ ${#scores[@]} -gt 0 ]]; then
        echo "Similar entries:"
        printf '%s\n' "${scores[@]}" | sort -rn | head -n "$limit" | while IFS=: read -r score entry_id; do
            # Find and display the entry
            find "$KNOWLEDGE_BASE" "$SOLUTIONS_DB" "$PATTERNS_DB" -name "$entry_id" -type d | while read -r entry_dir; do
                display_knowledge_entry "$entry_dir/metadata.json"
            done
        done
    fi
}

# Export knowledge for sharing
export_knowledge() {
    local export_file="${1:-knowledge_export_$(date +%Y%m%d_%H%M%S).tar.gz}"
    local category="${2:-all}"
    
    echo "Exporting knowledge base..."
    
    local temp_dir=$(mktemp -d)
    local export_dir="$temp_dir/knowledge_export"
    mkdir -p "$export_dir"
    
    # Copy relevant data
    if [[ "$category" == "all" ]]; then
        cp -r "$KNOWLEDGE_BASE"/* "$export_dir/" 2>/dev/null || true
        cp -r "$SOLUTIONS_DB"/* "$export_dir/" 2>/dev/null || true
        cp -r "$PATTERNS_DB"/* "$export_dir/" 2>/dev/null || true
    else
        mkdir -p "$export_dir/$category"
        cp -r "$KNOWLEDGE_BASE/$category"/* "$export_dir/$category/" 2>/dev/null || true
        cp -r "$SOLUTIONS_DB/$category"/* "$export_dir/$category/" 2>/dev/null || true
        cp -r "$PATTERNS_DB/$category"/* "$export_dir/$category/" 2>/dev/null || true
    fi
    
    # Add metadata
    cat > "$export_dir/export_metadata.json" <<EOF
{
    "export_date": "$(date -Iseconds)",
    "export_host": "$(hostname)",
    "export_user": "$USER",
    "category": "$category",
    "entry_count": $(find "$export_dir" -name "metadata.json" | wc -l)
}
EOF
    
    # Create archive
    tar -czf "$export_file" -C "$temp_dir" knowledge_export
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo "Knowledge exported to: $export_file"
}

# Import knowledge from export
import_knowledge() {
    local import_file="$1"
    local merge_strategy="${2:-merge}" # merge, replace, skip
    
    if [[ ! -f "$import_file" ]]; then
        echo "Error: Import file not found: $import_file"
        return 1
    fi
    
    echo "Importing knowledge from: $import_file"
    
    local temp_dir=$(mktemp -d)
    tar -xzf "$import_file" -C "$temp_dir"
    
    local import_dir="$temp_dir/knowledge_export"
    if [[ ! -d "$import_dir" ]]; then
        echo "Error: Invalid import file format"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Process imported entries
    local imported=0
    local skipped=0
    
    find "$import_dir" -name "metadata.json" | while read -r metadata_file; do
        local entry_dir=$(dirname "$metadata_file")
        local entry_id=$(jq -r '.id' "$metadata_file")
        local category=$(jq -r '.category' "$metadata_file")
        
        # Determine target directory
        local target_base=""
        if [[ -f "$entry_dir/content.md" ]]; then
            target_base="$KNOWLEDGE_BASE"
        elif [[ -f "$entry_dir/solution.md" ]]; then
            target_base="$SOLUTIONS_DB"
        elif [[ -f "$entry_dir/pattern.md" ]]; then
            target_base="$PATTERNS_DB"
        fi
        
        local target_dir="$target_base/$category/$entry_id"
        
        # Check if entry exists
        if [[ -d "$target_dir" ]]; then
            case "$merge_strategy" in
                merge)
                    # Merge with existing entry
                    merge_knowledge_entries "$entry_dir" "$target_dir"
                    ((imported++))
                    ;;
                replace)
                    # Replace existing entry
                    rm -rf "$target_dir"
                    cp -r "$entry_dir" "$target_dir"
                    ((imported++))
                    ;;
                skip)
                    # Skip existing entries
                    ((skipped++))
                    ;;
            esac
        else
            # New entry - import it
            mkdir -p "$(dirname "$target_dir")"
            cp -r "$entry_dir" "$target_dir"
            ((imported++))
        fi
    done
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Rebuild index
    create_knowledge_index
    
    echo "Import complete:"
    echo "  Imported: $imported entries"
    echo "  Skipped: $skipped entries"
}

# Analytics and insights
generate_insights() {
    echo "=== Knowledge Base Insights ==="
    echo
    
    # Entry statistics
    local total_entries=$(find "$KNOWLEDGE_BASE" "$SOLUTIONS_DB" "$PATTERNS_DB" -name "metadata.json" | wc -l)
    local knowledge_entries=$(find "$KNOWLEDGE_BASE" -name "metadata.json" | wc -l)
    local solution_entries=$(find "$SOLUTIONS_DB" -name "metadata.json" | wc -l)
    local pattern_entries=$(find "$PATTERNS_DB" -name "metadata.json" | wc -l)
    
    echo "Entry Statistics:"
    echo "  Total entries: $total_entries"
    echo "  Knowledge entries: $knowledge_entries"
    echo "  Solutions: $solution_entries"
    echo "  Patterns: $pattern_entries"
    echo
    
    # Category distribution
    echo "Category Distribution:"
    for category in "${!CATEGORIES[@]}"; do
        local count=$(find "$KNOWLEDGE_BASE/$category" "$SOLUTIONS_DB/$category" "$PATTERNS_DB/$category" -name "metadata.json" 2>/dev/null | wc -l)
        echo "  $category: $count"
    done
    echo
    
    # Most referenced entries
    echo "Most Used Entries:"
    find "$KNOWLEDGE_BASE" "$SOLUTIONS_DB" "$PATTERNS_DB" -name "metadata.json" | while read -r metadata; do
        local usage=$(jq -r '.usage_count // 0' "$metadata" 2>/dev/null)
        local title=$(jq -r '.title // .name // .problem' "$metadata" 2>/dev/null)
        echo "$usage:$title"
    done | sort -rn | head -5 | while IFS=: read -r count title; do
        echo "  $title (used $count times)"
    done
    echo
    
    # Effectiveness metrics
    echo "Solution Effectiveness:"
    local total_effectiveness=0
    local effective_count=0
    
    find "$SOLUTIONS_DB" -name "metadata.json" | while read -r metadata; do
        local effectiveness=$(jq -r '.effectiveness' "$metadata" 2>/dev/null)
        case "$effectiveness" in
            high) ((effective_count++)) ;;
            medium) ((effective_count++)) ;;
        esac
    done
    
    echo "  Highly effective solutions: $effective_count"
    echo
    
    # Recent activity
    echo "Recent Activity:"
    find "$KNOWLEDGE_BASE" "$SOLUTIONS_DB" "$PATTERNS_DB" -name "metadata.json" -mtime -7 | wc -l | while read -r count; do
        echo "  Entries added in last 7 days: $count"
    done
}

# Helper functions
generate_entry_id() {
    local timestamp=$(date +%s%N)
    local random=$(openssl rand -hex 4)
    echo "kb_${timestamp}_${random}"
}

create_knowledge_index() {
    # Create searchable index
    local index_file="$INDEX_DIR/main.idx"
    
    echo "Building knowledge index..."
    
    # Create index header
    cat > "$index_file" <<EOF
# Knowledge Base Index
# Generated: $(date -Iseconds)
# Format: entry_id|category|type|title|tags

EOF
    
    # Index all entries
    find "$KNOWLEDGE_BASE" "$SOLUTIONS_DB" "$PATTERNS_DB" -name "metadata.json" | while read -r metadata; do
        local entry_id=$(jq -r '.id' "$metadata")
        local category=$(jq -r '.category' "$metadata")
        local type=$(jq -r '.type // "unknown"' "$metadata")
        local title=$(jq -r '.title // .name // .problem' "$metadata")
        local tags=$(jq -r '.tags[]?' "$metadata" | tr '\n' ',')
        
        echo "$entry_id|$category|$type|$title|$tags" >> "$index_file"
    done
    
    echo "Index built with $(wc -l < "$index_file") entries"
}

index_entry() {
    local entry_id="$1"
    local category="$2"
    
    # Update index with new entry
    # [Implementation for incremental indexing]
    create_knowledge_index
}

link_solution_to_knowledge() {
    local solution_id="$1"
    local category="$2"
    
    # Create bidirectional links between solutions and knowledge entries
    # [Implementation for linking]
}

merge_knowledge_entries() {
    local source_dir="$1"
    local target_dir="$2"
    
    # Merge two knowledge entries intelligently
    # [Implementation for merging]
}

# Main function
main() {
    case "${1:-}" in
        init)
            init_knowledge_system
            ;;
        capture)
            shift
            capture_knowledge "$@"
            ;;
        solution)
            shift
            record_solution "$@"
            ;;
        pattern)
            shift
            identify_pattern "$@"
            ;;
        search)
            shift
            search_knowledge "$@"
            ;;
        learn)
            shift
            learn_from_history "$@"
            ;;
        export)
            shift
            export_knowledge "$@"
            ;;
        import)
            shift
            import_knowledge "$@"
            ;;
        insights)
            generate_insights
            ;;
        *)
            cat <<EOF
Knowledge Management System - Capture and retrieve organizational knowledge

Usage: $0 <command> [options]

Commands:
    init                Initialize knowledge management system
    capture             Capture new knowledge entry
    solution            Record a problem solution
    pattern             Identify a recurring pattern
    search              Search knowledge base
    learn               Learn from build history
    export              Export knowledge for sharing
    import              Import knowledge from export
    insights            Generate analytics and insights

Examples:
    # Initialize system
    $0 init
    
    # Capture knowledge
    $0 capture "Docker build optimization" "performance" "" "docker,build,optimization"
    
    # Record solution
    $0 solution "Build fails with OOM error" "Increase Docker memory limit to 4GB"
    
    # Search for solutions
    $0 search "memory error" "build_errors"
    
    # Learn from project history
    $0 learn /path/to/project build.log
    
    # Export knowledge
    $0 export my_knowledge.tar.gz

EOF
            ;;
    esac
}

main "$@"
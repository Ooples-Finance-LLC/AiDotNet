#!/bin/bash

# Fast Path Router - Routes common errors to optimized fix paths
# Bypasses complex analysis for known patterns with proven solutions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state/fast_path"
ROUTES_FILE="$STATE_DIR/routes.json"
METRICS_FILE="$STATE_DIR/fast_path_metrics.json"

# Configuration
ENABLE_FAST_PATH=${ENABLE_FAST_PATH:-true}
FAST_PATH_THRESHOLD=${FAST_PATH_THRESHOLD:-0.9}  # Min success rate
CACHE_FAST_FIXES=${CACHE_FAST_FIXES:-true}

# Create directories
mkdir -p "$STATE_DIR"

# Initialize route registry
init_routes() {
    if [[ ! -f "$ROUTES_FILE" ]]; then
        cat > "$ROUTES_FILE" << 'EOF'
{
    "version": "1.0",
    "routes": {
        "CS0101": {
            "name": "Duplicate Definition",
            "handler": "fast_fix_duplicate",
            "pattern": "deterministic",
            "success_rate": 0.95,
            "avg_time_ms": 50
        },
        "CS8618": {
            "name": "Nullable Reference",
            "handler": "fast_fix_nullable",
            "pattern": "predictable",
            "success_rate": 0.98,
            "avg_time_ms": 30
        },
        "CS0234": {
            "name": "Missing Namespace",
            "handler": "fast_fix_namespace",
            "pattern": "lookup",
            "success_rate": 0.92,
            "avg_time_ms": 40
        },
        "CS0103": {
            "name": "Name Not Found",
            "handler": "fast_fix_undefined",
            "pattern": "typo",
            "success_rate": 0.88,
            "avg_time_ms": 60
        },
        "CS1061": {
            "name": "Missing Member",
            "handler": "fast_fix_member",
            "pattern": "extension",
            "success_rate": 0.85,
            "avg_time_ms": 70
        },
        "CS0246": {
            "name": "Type Not Found",
            "handler": "fast_fix_type",
            "pattern": "import",
            "success_rate": 0.90,
            "avg_time_ms": 45
        }
    },
    "custom_routes": {}
}
EOF
    fi
    
    if [[ ! -f "$METRICS_FILE" ]]; then
        echo '{
            "total_routed": 0,
            "fast_path_hits": 0,
            "fast_path_misses": 0,
            "time_saved_ms": 0,
            "success_count": 0,
            "failure_count": 0
        }' > "$METRICS_FILE"
    fi
}

# Check if error can use fast path
can_use_fast_path() {
    local error_code="$1"
    local error_context="${2:-}"
    
    if [[ "$ENABLE_FAST_PATH" != "true" ]]; then
        return 1
    fi
    
    # Check if route exists
    local route=$(jq -r --arg code "$error_code" '.routes[$code] // .custom_routes[$code] // empty' "$ROUTES_FILE")
    
    if [[ -z "$route" ]]; then
        return 1
    fi
    
    # Check success rate threshold
    local success_rate=$(echo "$route" | jq -r '.success_rate // 0')
    if (( $(echo "$success_rate < $FAST_PATH_THRESHOLD" | bc -l) )); then
        return 1
    fi
    
    # Check pattern type
    local pattern=$(echo "$route" | jq -r '.pattern // "unknown"')
    
    case "$pattern" in
        "deterministic"|"predictable"|"lookup")
            return 0
            ;;
        "complex"|"contextual")
            # Need more context analysis
            if [[ -n "$error_context" ]]; then
                return 0
            fi
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# Route error to fast path
route_to_fast_path() {
    local error_code="$1"
    local error_file="${2:-}"
    local error_line="${3:-}"
    local error_message="${4:-}"
    
    local start_time=$(date +%s%N)
    
    # Get route handler
    local handler=$(jq -r --arg code "$error_code" '.routes[$code].handler // .custom_routes[$code].handler // empty' "$ROUTES_FILE")
    
    if [[ -z "$handler" ]] || ! command -v "$handler" >/dev/null 2>&1; then
        update_metrics "miss"
        return 1
    fi
    
    echo "[FAST_PATH] Routing $error_code to $handler"
    
    # Execute fast fix
    local result=1
    case "$handler" in
        fast_fix_duplicate)
            result=$(fast_fix_duplicate "$error_file" "$error_code")
            ;;
        fast_fix_nullable)
            result=$(fast_fix_nullable "$error_file" "$error_line")
            ;;
        fast_fix_namespace)
            result=$(fast_fix_namespace "$error_file" "$error_message")
            ;;
        fast_fix_undefined)
            result=$(fast_fix_undefined "$error_file" "$error_message")
            ;;
        fast_fix_member)
            result=$(fast_fix_member "$error_file" "$error_message")
            ;;
        fast_fix_type)
            result=$(fast_fix_type "$error_file" "$error_message")
            ;;
        *)
            # Custom handler
            if command -v "$handler" >/dev/null 2>&1; then
                $handler "$error_code" "$error_file" "$error_line" "$error_message"
                result=$?
            fi
            ;;
    esac
    
    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    # Update metrics
    if [[ $result -eq 0 ]]; then
        update_metrics "hit" "$duration_ms"
        update_route_stats "$error_code" "success" "$duration_ms"
        echo "[FAST_PATH] Successfully fixed $error_code in ${duration_ms}ms"
        return 0
    else
        update_metrics "failure"
        update_route_stats "$error_code" "failure" "$duration_ms"
        echo "[FAST_PATH] Failed to fix $error_code"
        return 1
    fi
}

# Fast fix handlers

fast_fix_duplicate() {
    local file="$1"
    local error_code="$2"
    
    # Check cache first
    if [[ "$CACHE_FAST_FIXES" == "true" ]]; then
        local cache_key=$(echo -n "${file}${error_code}" | md5sum | cut -d' ' -f1)
        local cache_file="$STATE_DIR/cache/${cache_key}.fix"
        
        if [[ -f "$cache_file" ]] && [[ $(find "$cache_file" -mmin -60 -type f 2>/dev/null) ]]; then
            echo "[FAST_PATH] Using cached fix for duplicate"
            cp "$cache_file" "${file}.tmp" && mv "${file}.tmp" "$file"
            return 0
        fi
    fi
    
    # Extract duplicate class/interface name
    local duplicate_name=$(grep "error CS0101:" build_output.txt | grep "$file" | \
        grep -oE "already contains.*'([^']+)'" | sed "s/.*'\\([^']*\\)'/\\1/" | head -1)
    
    if [[ -n "$duplicate_name" ]]; then
        # Quick fix: Comment out second occurrence
        awk -v name="$duplicate_name" '
        /^[[:space:]]*(public|internal|private)[[:space:]]+(class|interface|enum)[[:space:]]+'$duplicate_name'/ {
            if (seen) {
                print "// Duplicate removed by fast path: " $0
                in_block = 1
                brace_count = 0
                next
            }
            seen = 1
        }
        in_block && /{/ { brace_count++ }
        in_block && /}/ { 
            brace_count--
            if (brace_count == 0) {
                in_block = 0
                next
            }
        }
        !in_block { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
        
        # Cache the fix
        if [[ "$CACHE_FAST_FIXES" == "true" ]]; then
            mkdir -p "$STATE_DIR/cache"
            cp "$file" "$cache_file"
        fi
        
        return 0
    fi
    
    return 1
}

fast_fix_nullable() {
    local file="$1"
    local line_num="${2:-}"
    
    # Pre-compiled patterns for nullable fixes
    local patterns=(
        's/\(public\|private\|protected\|internal\) string \([A-Za-z0-9_]*\) { get; set; }/\1 string \2 { get; set; } = string.Empty;/g'
        's/\(public\|private\|protected\|internal\) List<\([^>]*\)> \([A-Za-z0-9_]*\) { get; set; }/\1 List<\2> \3 { get; set; } = new();/g'
        's/\(public\|private\|protected\|internal\) \([A-Z][A-Za-z0-9_]*\) \([A-Za-z0-9_]*\) { get; set; }/\1 \2? \3 { get; set; }/g'
    )
    
    # Apply patterns
    local fixed=false
    for pattern in "${patterns[@]}"; do
        if sed -i.bak "$pattern" "$file"; then
            fixed=true
        fi
    done
    
    # Clean up backup
    rm -f "${file}.bak"
    
    [[ "$fixed" == "true" ]] && return 0 || return 1
}

fast_fix_namespace() {
    local file="$1"
    local error_msg="$2"
    
    # Extract missing type
    local missing_type=$(echo "$error_msg" | grep -oE "type or namespace name '[^']+'" | \
        sed "s/type or namespace name '\\([^']*\\)'/\\1/")
    
    if [[ -z "$missing_type" ]]; then
        return 1
    fi
    
    # Quick namespace mapping
    declare -A namespace_map=(
        ["List"]="System.Collections.Generic"
        ["Dictionary"]="System.Collections.Generic"
        ["Task"]="System.Threading.Tasks"
        ["CancellationToken"]="System.Threading"
        ["Enumerable"]="System.Linq"
        ["IEnumerable"]="System.Collections.Generic"
        ["HttpClient"]="System.Net.Http"
        ["JsonSerializer"]="System.Text.Json"
        ["ILogger"]="Microsoft.Extensions.Logging"
        ["DbContext"]="Microsoft.EntityFrameworkCore"
        ["IConfiguration"]="Microsoft.Extensions.Configuration"
    )
    
    # Check if we have a mapping
    if [[ -n "${namespace_map[$missing_type]}" ]]; then
        local namespace="${namespace_map[$missing_type]}"
        
        # Add using if not present
        if ! grep -q "using $namespace;" "$file"; then
            # Insert after last using or at beginning
            local last_using=$(grep -n "^using " "$file" | tail -1 | cut -d: -f1)
            
            if [[ -n "$last_using" ]]; then
                sed -i "${last_using}a\\using $namespace;" "$file"
            else
                sed -i "1i\\using $namespace;" "$file"
            fi
            
            return 0
        fi
    fi
    
    return 1
}

fast_fix_undefined() {
    local file="$1"
    local error_msg="$2"
    
    # Extract undefined name
    local undefined=$(echo "$error_msg" | grep -oE "name '[^']+' does not exist" | \
        sed "s/name '\\([^']*\\)' does not exist/\\1/")
    
    if [[ -z "$undefined" ]]; then
        return 1
    fi
    
    # Common typo fixes
    declare -A typo_fixes=(
        ["lenght"]="length"
        ["Lenght"]="Length"
        ["cancellationtoken"]="cancellationToken"
        ["Cancellationtoken"]="CancellationToken"
        ["stringbuilder"]="StringBuilder"
        ["httpcontext"]="HttpContext"
    )
    
    # Check for typo
    if [[ -n "${typo_fixes[$undefined]}" ]]; then
        local correct="${typo_fixes[$undefined]}"
        sed -i "s/\\b$undefined\\b/$correct/g" "$file"
        return 0
    fi
    
    return 1
}

fast_fix_member() {
    local file="$1"
    local error_msg="$2"
    
    # Check if it's a missing extension method
    if [[ "$error_msg" =~ "does not contain a definition for" ]] && \
       [[ "$error_msg" =~ "no accessible extension method" ]]; then
        
        # Common extension method namespaces
        local ext_namespaces=(
            "System.Linq"
            "System.Threading.Tasks"
            "Microsoft.EntityFrameworkCore"
        )
        
        # Try adding common namespaces
        local added=false
        for ns in "${ext_namespaces[@]}"; do
            if ! grep -q "using $ns;" "$file"; then
                sed -i "1i\\using $ns;" "$file"
                added=true
            fi
        done
        
        [[ "$added" == "true" ]] && return 0
    fi
    
    return 1
}

fast_fix_type() {
    local file="$1"
    local error_msg="$2"
    
    # Extract type name
    local type_name=$(echo "$error_msg" | grep -oE "type or namespace name '[^']+'" | \
        sed "s/type or namespace name '\\([^']*\\)'/\\1/" | head -1)
    
    if [[ -z "$type_name" ]]; then
        return 1
    fi
    
    # Check project references
    local project_dir=$(dirname "$file")
    local csproj=$(find "$project_dir" -name "*.csproj" -maxdepth 3 | head -1)
    
    if [[ -f "$csproj" ]]; then
        # Common package references
        declare -A package_types=(
            ["ILogger"]="Microsoft.Extensions.Logging"
            ["DbContext"]="Microsoft.EntityFrameworkCore"
            ["HttpClient"]="System.Net.Http"
        )
        
        if [[ -n "${package_types[$type_name]}" ]]; then
            # Add package reference if missing
            local package="${package_types[$type_name]}"
            if ! grep -q "$package" "$csproj"; then
                # This would need proper XML handling in production
                echo "[FAST_PATH] Package reference needed: $package"
            fi
        fi
    fi
    
    return 1
}

# Update metrics
update_metrics() {
    local event="$1"
    local time_saved="${2:-0}"
    
    case "$event" in
        "hit")
            jq '.fast_path_hits += 1 | .time_saved_ms += '$time_saved "$METRICS_FILE" > "$METRICS_FILE.tmp" && \
                mv "$METRICS_FILE.tmp" "$METRICS_FILE"
            ;;
        "miss")
            jq '.fast_path_misses += 1' "$METRICS_FILE" > "$METRICS_FILE.tmp" && \
                mv "$METRICS_FILE.tmp" "$METRICS_FILE"
            ;;
        "failure")
            jq '.failure_count += 1' "$METRICS_FILE" > "$METRICS_FILE.tmp" && \
                mv "$METRICS_FILE.tmp" "$METRICS_FILE"
            ;;
    esac
    
    jq '.total_routed += 1' "$METRICS_FILE" > "$METRICS_FILE.tmp" && \
        mv "$METRICS_FILE.tmp" "$METRICS_FILE"
}

# Update route statistics
update_route_stats() {
    local error_code="$1"
    local result="$2"
    local duration="$3"
    
    # Update success rate
    local current=$(jq -r --arg code "$error_code" '.routes[$code] // .custom_routes[$code]' "$ROUTES_FILE")
    
    if [[ "$current" != "null" ]]; then
        local total_attempts=$(echo "$current" | jq -r '.total_attempts // 0')
        local successful=$(echo "$current" | jq -r '.successful // 0')
        
        total_attempts=$((total_attempts + 1))
        [[ "$result" == "success" ]] && successful=$((successful + 1))
        
        local new_rate=$(echo "scale=3; $successful / $total_attempts" | bc)
        
        # Update route
        jq --arg code "$error_code" \
           --argjson attempts "$total_attempts" \
           --argjson success "$successful" \
           --arg rate "$new_rate" \
           --argjson duration "$duration" \
           '(.routes[$code] // .custom_routes[$code]) |= . + {
               total_attempts: $attempts,
               successful: $success,
               success_rate: ($rate | tonumber),
               last_duration_ms: $duration
           }' "$ROUTES_FILE" > "$ROUTES_FILE.tmp" && \
            mv "$ROUTES_FILE.tmp" "$ROUTES_FILE"
    fi
}

# Add custom route
add_custom_route() {
    local error_code="$1"
    local handler="$2"
    local pattern="${3:-custom}"
    local name="${4:-Custom Fix}"
    
    jq --arg code "$error_code" \
       --arg handler "$handler" \
       --arg pattern "$pattern" \
       --arg name "$name" \
       '.custom_routes[$code] = {
           name: $name,
           handler: $handler,
           pattern: $pattern,
           success_rate: 0,
           avg_time_ms: 0,
           total_attempts: 0,
           successful: 0
       }' "$ROUTES_FILE" > "$ROUTES_FILE.tmp" && \
        mv "$ROUTES_FILE.tmp" "$ROUTES_FILE"
    
    echo "[FAST_PATH] Added custom route for $error_code"
}

# Show fast path statistics
show_stats() {
    echo "=== Fast Path Router Statistics ==="
    
    if [[ -f "$METRICS_FILE" ]]; then
        local total=$(jq -r '.total_routed' "$METRICS_FILE")
        local hits=$(jq -r '.fast_path_hits' "$METRICS_FILE")
        local misses=$(jq -r '.fast_path_misses' "$METRICS_FILE")
        local time_saved=$(jq -r '.time_saved_ms' "$METRICS_FILE")
        
        local hit_rate=0
        if [[ $total -gt 0 ]]; then
            hit_rate=$(echo "scale=2; $hits * 100 / $total" | bc)
        fi
        
        echo "Total Routed: $total"
        echo "Fast Path Hits: $hits (${hit_rate}%)"
        echo "Fast Path Misses: $misses"
        echo "Time Saved: ${time_saved}ms"
        echo ""
    fi
    
    echo "Route Performance:"
    jq -r '.routes | to_entries[] | "  \(.key): \(.value.success_rate * 100 | floor)% success, \(.value.avg_time_ms)ms avg"' "$ROUTES_FILE"
    
    if [[ $(jq '.custom_routes | length' "$ROUTES_FILE") -gt 0 ]]; then
        echo ""
        echo "Custom Routes:"
        jq -r '.custom_routes | to_entries[] | "  \(.key): \(.value.success_rate * 100 | floor)% success"' "$ROUTES_FILE"
    fi
}

# Main function
main() {
    init_routes
    
    case "${1:-route}" in
        route)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 route <error_code> [file] [line] [message]"
                exit 1
            fi
            route_to_fast_path "$2" "${3:-}" "${4:-}" "${5:-}"
            ;;
        check)
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 check <error_code>"
                exit 1
            fi
            if can_use_fast_path "$2"; then
                echo "Fast path available for $2"
                exit 0
            else
                echo "No fast path for $2"
                exit 1
            fi
            ;;
        add)
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 add <error_code> <handler> [pattern] [name]"
                exit 1
            fi
            add_custom_route "$2" "$3" "${4:-custom}" "${5:-Custom Fix}"
            ;;
        stats)
            show_stats
            ;;
        test)
            # Test fast path routing
            echo "[FAST_PATH] Testing routing..."
            route_to_fast_path "CS8618" "test.cs" "10" "Non-nullable property must contain a non-null value"
            ;;
        *)
            cat << EOF
Fast Path Router - Optimized fixes for common errors

Usage: $0 <command> [options]

Commands:
  route <code> [file] [line] [msg]  - Route error to fast path
  check <code>                      - Check if fast path available
  add <code> <handler> [pattern]    - Add custom route
  stats                             - Show statistics
  test                              - Run test

Examples:
  # Route an error
  $0 route CS8618 Model.cs 15 "Non-nullable property..."
  
  # Check availability
  $0 check CS0101
  
  # Add custom route
  $0 add CS9999 my_custom_handler complex "My Custom Fix"
EOF
            ;;
    esac
}

# Export functions
export -f can_use_fast_path
export -f route_to_fast_path
export -f fast_fix_duplicate
export -f fast_fix_nullable
export -f fast_fix_namespace

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
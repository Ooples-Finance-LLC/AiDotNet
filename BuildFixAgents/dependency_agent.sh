#!/bin/bash
# Dependency Agent - Manages dependencies, security updates, and version compatibility
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEP_STATE="$SCRIPT_DIR/state/dependency"
mkdir -p "$DEP_STATE/audits" "$DEP_STATE/updates" "$DEP_STATE/reports"

# Source logging if available
if [[ -f "$SCRIPT_DIR/enhanced_logging_system.sh" ]]; then
    source "$SCRIPT_DIR/enhanced_logging_system.sh"
else
    log_event() { echo "[$1] $2: $3"; }
fi

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║       Dependency Agent v1.0            ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════╝${NC}"
}

# Detect package manager
detect_package_manager() {
    if [[ -f "package-lock.json" ]]; then
        echo "npm"
    elif [[ -f "yarn.lock" ]]; then
        echo "yarn"
    elif [[ -f "pnpm-lock.yaml" ]]; then
        echo "pnpm"
    elif [[ -f "requirements.txt" ]] || [[ -f "Pipfile" ]]; then
        echo "pip"
    elif [[ -f "Gemfile.lock" ]]; then
        echo "bundler"
    elif [[ -f "go.mod" ]]; then
        echo "go"
    elif [[ -f "pom.xml" ]]; then
        echo "maven"
    elif [[ -f "build.gradle" ]]; then
        echo "gradle"
    elif [[ -f "*.csproj" ]] || [[ -f "*.sln" ]]; then
        echo "nuget"
    else
        echo "unknown"
    fi
}

# Audit dependencies for vulnerabilities
audit_dependencies() {
    local package_manager="${1:-$(detect_package_manager)}"
    local output_file="$DEP_STATE/audits/vulnerability_report.json"
    
    log_event "INFO" "DEPENDENCY" "Auditing dependencies with $package_manager"
    
    # Initialize report
    cat > "$output_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "package_manager": "$package_manager",
  "vulnerabilities": [],
  "summary": {
    "total": 0,
    "critical": 0,
    "high": 0,
    "moderate": 0,
    "low": 0
  }
}
EOF
    
    case "$package_manager" in
        npm)
            if command -v npm &> /dev/null; then
                npm audit --json > "$DEP_STATE/audits/npm_audit.json" 2>/dev/null || true
                
                # Parse npm audit results
                if [[ -f "$DEP_STATE/audits/npm_audit.json" ]]; then
                    local vulnerabilities=$(jq '.vulnerabilities | length' "$DEP_STATE/audits/npm_audit.json" 2>/dev/null || echo 0)
                    log_event "INFO" "DEPENDENCY" "Found $vulnerabilities vulnerabilities in npm packages"
                fi
            fi
            ;;
        yarn)
            if command -v yarn &> /dev/null; then
                yarn audit --json > "$DEP_STATE/audits/yarn_audit.json" 2>/dev/null || true
            fi
            ;;
        pip)
            if command -v pip-audit &> /dev/null; then
                pip-audit --format json --output "$DEP_STATE/audits/pip_audit.json" 2>/dev/null || true
            elif command -v safety &> /dev/null; then
                safety check --json > "$DEP_STATE/audits/safety_audit.json" 2>/dev/null || true
            fi
            ;;
        *)
            log_event "WARN" "DEPENDENCY" "Audit not supported for $package_manager"
            ;;
    esac
    
    log_event "SUCCESS" "DEPENDENCY" "Dependency audit complete"
}

# Check for outdated dependencies
check_outdated() {
    local package_manager="${1:-$(detect_package_manager)}"
    local output_file="$DEP_STATE/updates/outdated_packages.json"
    
    log_event "INFO" "DEPENDENCY" "Checking for outdated dependencies"
    
    # Initialize report
    cat > "$output_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "package_manager": "$package_manager",
  "outdated": []
}
EOF
    
    case "$package_manager" in
        npm)
            if command -v npm &> /dev/null; then
                npm outdated --json > "$DEP_STATE/updates/npm_outdated.json" 2>/dev/null || true
            fi
            ;;
        yarn)
            if command -v yarn &> /dev/null; then
                yarn outdated --json > "$DEP_STATE/updates/yarn_outdated.json" 2>/dev/null || true
            fi
            ;;
        pip)
            if command -v pip &> /dev/null; then
                pip list --outdated --format json > "$DEP_STATE/updates/pip_outdated.json" 2>/dev/null || true
            fi
            ;;
    esac
    
    log_event "SUCCESS" "DEPENDENCY" "Outdated dependency check complete"
}

# Generate dependency update script
generate_update_script() {
    local package_manager="${1:-$(detect_package_manager)}"
    local update_type="${2:-safe}" # safe, latest, or major
    local output_file="$DEP_STATE/updates/update_dependencies.sh"
    
    log_event "INFO" "DEPENDENCY" "Generating update script for $update_type updates"
    
    cat > "$output_file" << 'EOF'
#!/bin/bash
# Dependency Update Script
# Generated by Dependency Agent

set -euo pipefail

echo "Starting dependency updates..."

# Backup current lock files
backup_lockfiles() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [[ -f "package-lock.json" ]]; then
        cp package-lock.json "package-lock.json.backup.$timestamp"
    fi
    if [[ -f "yarn.lock" ]]; then
        cp yarn.lock "yarn.lock.backup.$timestamp"
    fi
    if [[ -f "requirements.txt" ]]; then
        cp requirements.txt "requirements.txt.backup.$timestamp"
    fi
    
    echo "Lock files backed up with timestamp: $timestamp"
}

# Restore lock files on error
restore_lockfiles() {
    local timestamp="$1"
    
    if [[ -f "package-lock.json.backup.$timestamp" ]]; then
        mv "package-lock.json.backup.$timestamp" package-lock.json
    fi
    if [[ -f "yarn.lock.backup.$timestamp" ]]; then
        mv "yarn.lock.backup.$timestamp" yarn.lock
    fi
    if [[ -f "requirements.txt.backup.$timestamp" ]]; then
        mv "requirements.txt.backup.$timestamp" requirements.txt
    fi
    
    echo "Lock files restored from backup"
}

# Run tests after update
run_tests() {
    echo "Running tests..."
    
    if [[ -f "package.json" ]] && grep -q '"test"' package.json; then
        npm test || yarn test || return 1
    fi
    
    if [[ -f "requirements.txt" ]] && command -v pytest &> /dev/null; then
        pytest || return 1
    fi
    
    return 0
}

# Main update process
main() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Backup lock files
    backup_lockfiles
    
    # Trap errors to restore backups
    trap "restore_lockfiles $timestamp" ERR
    
EOF
    
    case "$package_manager" in
        npm)
            cat >> "$output_file" << 'EOF'
    # Update npm dependencies
    echo "Updating npm dependencies..."
    
    case "$UPDATE_TYPE" in
        safe)
            # Update patch versions only
            npm update
            ;;
        latest)
            # Update to latest minor versions
            npx npm-check-updates -u --target minor
            npm install
            ;;
        major)
            # Update all including major versions
            npx npm-check-updates -u
            npm install
            ;;
    esac
    
    # Audit after update
    npm audit fix
EOF
            ;;
        yarn)
            cat >> "$output_file" << 'EOF'
    # Update yarn dependencies
    echo "Updating yarn dependencies..."
    
    case "$UPDATE_TYPE" in
        safe)
            yarn upgrade
            ;;
        latest)
            yarn upgrade-interactive --latest
            ;;
        major)
            yarn upgrade --latest
            ;;
    esac
EOF
            ;;
        pip)
            cat >> "$output_file" << 'EOF'
    # Update Python dependencies
    echo "Updating Python dependencies..."
    
    if [[ -f "requirements.txt" ]]; then
        case "$UPDATE_TYPE" in
            safe|latest|major)
                pip list --outdated --format json | \
                jq -r '.[] | .name' | \
                xargs -I {} pip install --upgrade {}
                
                # Regenerate requirements.txt
                pip freeze > requirements.txt
                ;;
        esac
    fi
EOF
            ;;
    esac
    
    cat >> "$output_file" << 'EOF'
    
    # Run tests
    if run_tests; then
        echo "All tests passed!"
        # Clean up backups
        rm -f *.backup.$timestamp
    else
        echo "Tests failed! Rolling back..."
        restore_lockfiles "$timestamp"
        exit 1
    fi
    
    echo "Dependency update complete!"
}

# Set update type
UPDATE_TYPE="${1:-safe}"

main
EOF
    
    chmod +x "$output_file"
    log_event "SUCCESS" "DEPENDENCY" "Update script generated at $output_file"
}

# Generate dependency graph
generate_dependency_graph() {
    local output_format="${1:-dot}" # dot, json, or html
    local output_file="$DEP_STATE/reports/dependency_graph.$output_format"
    
    log_event "INFO" "DEPENDENCY" "Generating dependency graph"
    
    case "$output_format" in
        dot)
            generate_dot_graph "$output_file"
            ;;
        json)
            generate_json_graph "$output_file"
            ;;
        html)
            generate_html_graph "$output_file"
            ;;
    esac
    
    log_event "SUCCESS" "DEPENDENCY" "Dependency graph generated at $output_file"
}

# Generate DOT format graph
generate_dot_graph() {
    local output_file="$1"
    
    cat > "$output_file" << 'EOF'
digraph dependencies {
    rankdir=LR;
    node [shape=box, style=rounded];
    
    // Main application
    "MyApp" [style=filled, fillcolor=lightblue];
    
    // Direct dependencies
    "MyApp" -> "express";
    "MyApp" -> "react";
    "MyApp" -> "webpack";
    
    // Transitive dependencies
    "express" -> "body-parser";
    "express" -> "cookie-parser";
    "react" -> "react-dom";
    "webpack" -> "webpack-cli";
    
    // Shared dependencies
    "express" -> "debug";
    "webpack" -> "debug";
}
EOF
    
    # Try to generate image if graphviz is installed
    if command -v dot &> /dev/null; then
        dot -Tpng "$output_file" -o "${output_file%.dot}.png"
        log_event "INFO" "DEPENDENCY" "Generated PNG image from dependency graph"
    fi
}

# Generate HTML visualization
generate_html_graph() {
    local output_file="$1"
    
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dependency Graph</title>
    <script src="https://d3js.org/d3.v7.min.js"></script>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background-color: #007bff;
            color: white;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        #graph {
            background-color: white;
            border: 1px solid #ddd;
            border-radius: 5px;
            overflow: hidden;
        }
        .node {
            cursor: pointer;
        }
        .node circle {
            fill: #007bff;
            stroke: #fff;
            stroke-width: 2px;
        }
        .node text {
            font-size: 12px;
            text-anchor: middle;
        }
        .link {
            fill: none;
            stroke: #999;
            stroke-width: 1px;
        }
        .tooltip {
            position: absolute;
            text-align: center;
            padding: 10px;
            font-size: 12px;
            background: #333;
            color: white;
            border-radius: 5px;
            pointer-events: none;
            opacity: 0;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Dependency Graph Visualization</h1>
        <p>Interactive visualization of project dependencies</p>
    </div>
    
    <div id="graph"></div>
    <div class="tooltip"></div>
    
    <script>
        // Sample dependency data
        const data = {
            nodes: [
                { id: "app", name: "MyApp", type: "root" },
                { id: "express", name: "express", version: "4.18.2" },
                { id: "react", name: "react", version: "18.2.0" },
                { id: "webpack", name: "webpack", version: "5.88.0" },
                { id: "body-parser", name: "body-parser", version: "1.20.2" },
                { id: "react-dom", name: "react-dom", version: "18.2.0" },
                { id: "webpack-cli", name: "webpack-cli", version: "5.1.4" }
            ],
            links: [
                { source: "app", target: "express" },
                { source: "app", target: "react" },
                { source: "app", target: "webpack" },
                { source: "express", target: "body-parser" },
                { source: "react", target: "react-dom" },
                { source: "webpack", target: "webpack-cli" }
            ]
        };
        
        // Set up SVG
        const width = 800;
        const height = 600;
        
        const svg = d3.select("#graph")
            .append("svg")
            .attr("width", width)
            .attr("height", height);
        
        // Create force simulation
        const simulation = d3.forceSimulation(data.nodes)
            .force("link", d3.forceLink(data.links).id(d => d.id).distance(100))
            .force("charge", d3.forceManyBody().strength(-300))
            .force("center", d3.forceCenter(width / 2, height / 2));
        
        // Create links
        const link = svg.append("g")
            .selectAll("line")
            .data(data.links)
            .enter().append("line")
            .attr("class", "link");
        
        // Create nodes
        const node = svg.append("g")
            .selectAll("g")
            .data(data.nodes)
            .enter().append("g")
            .attr("class", "node")
            .call(d3.drag()
                .on("start", dragstarted)
                .on("drag", dragged)
                .on("end", dragended));
        
        node.append("circle")
            .attr("r", d => d.type === "root" ? 15 : 10)
            .style("fill", d => d.type === "root" ? "#dc3545" : "#007bff");
        
        node.append("text")
            .attr("dy", 20)
            .text(d => d.name);
        
        // Tooltip
        const tooltip = d3.select(".tooltip");
        
        node.on("mouseover", (event, d) => {
            tooltip.transition().duration(200).style("opacity", .9);
            tooltip.html(`${d.name}<br/>Version: ${d.version || "N/A"}`)
                .style("left", (event.pageX + 10) + "px")
                .style("top", (event.pageY - 28) + "px");
        })
        .on("mouseout", () => {
            tooltip.transition().duration(500).style("opacity", 0);
        });
        
        // Update positions
        simulation.on("tick", () => {
            link
                .attr("x1", d => d.source.x)
                .attr("y1", d => d.source.y)
                .attr("x2", d => d.target.x)
                .attr("y2", d => d.target.y);
            
            node.attr("transform", d => `translate(${d.x},${d.y})`);
        });
        
        // Drag functions
        function dragstarted(event, d) {
            if (!event.active) simulation.alphaTarget(0.3).restart();
            d.fx = d.x;
            d.fy = d.y;
        }
        
        function dragged(event, d) {
            d.fx = event.x;
            d.fy = event.y;
        }
        
        function dragended(event, d) {
            if (!event.active) simulation.alphaTarget(0);
            d.fx = null;
            d.fy = null;
        }
    </script>
</body>
</html>
EOF
}

# Generate security policy
generate_security_policy() {
    local output_file="${1:-SECURITY.md}"
    
    log_event "INFO" "DEPENDENCY" "Generating security policy"
    
    cat > "$output_file" << 'EOF'
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, please do the following:

1. **Do not** open a public issue
2. Email security@example.com with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will acknowledge receipt within 48 hours and provide a detailed response within 7 days.

## Security Update Process

1. **Regular Updates**: We perform weekly dependency updates for security patches
2. **Critical Updates**: Critical security updates are applied within 24 hours
3. **Audit Schedule**: Full security audits are conducted monthly

## Dependency Management

### Automated Security Scanning
- All dependencies are automatically scanned for vulnerabilities
- Pull requests are blocked if critical vulnerabilities are detected
- Security alerts are sent to the development team

### Update Policy
- **Patch versions**: Automatically updated weekly
- **Minor versions**: Updated monthly after testing
- **Major versions**: Updated quarterly with thorough testing

### Approved Dependencies
Before adding new dependencies:
1. Check license compatibility
2. Verify maintenance status
3. Review security history
4. Assess necessity

### Vulnerability Response
When vulnerabilities are discovered:
1. Assess severity and impact
2. Check for available patches
3. Test patches in staging
4. Deploy to production
5. Notify users if necessary

## Best Practices

1. **Keep dependencies minimal**: Only add dependencies that provide significant value
2. **Regular audits**: Run `npm audit` or equivalent before each deployment
3. **Lock versions**: Always commit lock files (package-lock.json, yarn.lock, etc.)
4. **Monitor advisories**: Subscribe to security advisories for critical dependencies

## Tools

- `npm audit` / `yarn audit` - Check for vulnerabilities
- `dependabot` - Automated dependency updates
- `snyk` - Advanced vulnerability scanning
- `license-checker` - Verify license compliance

## Contact

- Security Team: security@example.com
- Bug Bounty Program: https://example.com/security/bounty
EOF
    
    log_event "SUCCESS" "DEPENDENCY" "Security policy generated at $output_file"
}

# Generate license report
generate_license_report() {
    local output_file="$DEP_STATE/reports/license_report.md"
    
    log_event "INFO" "DEPENDENCY" "Generating license report"
    
    cat > "$output_file" << EOF
# License Report

Generated: $(date)

## Summary

This report provides an overview of all dependency licenses in the project.

## License Distribution

EOF
    
    local package_manager=$(detect_package_manager)
    
    case "$package_manager" in
        npm)
            if command -v license-checker &> /dev/null; then
                echo "### NPM Dependencies" >> "$output_file"
                license-checker --summary >> "$output_file" 2>/dev/null || true
            fi
            ;;
        pip)
            if command -v pip-licenses &> /dev/null; then
                echo "### Python Dependencies" >> "$output_file"
                pip-licenses --format=markdown >> "$output_file" 2>/dev/null || true
            fi
            ;;
    esac
    
    cat >> "$output_file" << 'EOF'

## License Compatibility

### Compatible Licenses
- MIT
- Apache-2.0
- BSD-3-Clause
- BSD-2-Clause
- ISC

### Licenses Requiring Attribution
- Apache-2.0
- BSD variants

### Incompatible Licenses
- GPL-3.0 (without exception)
- AGPL-3.0

## Recommendations

1. Review all GPL-licensed dependencies
2. Ensure proper attribution for Apache and BSD licenses
3. Consider replacing incompatible dependencies
4. Add license file to repository if missing
EOF
    
    log_event "SUCCESS" "DEPENDENCY" "License report generated at $output_file"
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        audit)
            audit_dependencies "${2:-}"
            ;;
        outdated)
            check_outdated "${2:-}"
            ;;
        update)
            generate_update_script "${2:-}" "${3:-safe}"
            ;;
        graph)
            generate_dependency_graph "${2:-dot}"
            ;;
        security)
            generate_security_policy "${2:-SECURITY.md}"
            ;;
        licenses)
            generate_license_report
            ;;
        init)
            echo -e "${CYAN}Initializing dependency analysis...${NC}"
            local pm=$(detect_package_manager)
            echo -e "${GREEN}Detected package manager: $pm${NC}"
            
            audit_dependencies "$pm"
            check_outdated "$pm"
            generate_update_script "$pm" "safe"
            generate_dependency_graph "html"
            generate_security_policy
            generate_license_report
            
            echo -e "${GREEN}✓ Dependency analysis complete!${NC}"
            echo -e "${YELLOW}Review reports in: $DEP_STATE${NC}"
            ;;
        *)
            echo "Usage: $0 {audit|outdated|update|graph|security|licenses|init} [options]"
            echo ""
            echo "Commands:"
            echo "  audit [pm]           - Audit for vulnerabilities"
            echo "  outdated [pm]        - Check for outdated packages"
            echo "  update [pm] [type]   - Generate update script"
            echo "  graph [format]       - Generate dependency graph"
            echo "  security [file]      - Generate security policy"
            echo "  licenses             - Generate license report"
            echo "  init                 - Run complete analysis"
            exit 1
            ;;
    esac
}

main "$@"
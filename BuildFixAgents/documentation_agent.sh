#!/bin/bash
# Documentation Agent - Automatically generates and maintains documentation
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOC_STATE="$SCRIPT_DIR/state/documentation"
mkdir -p "$DOC_STATE"

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
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║      Documentation Agent v1.0          ║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════╝${NC}"
}

# Detect project type and structure
detect_project() {
    local project_type="unknown"
    local main_language="unknown"
    
    # Detect by file patterns
    if [[ -f "package.json" ]]; then
        project_type="node"
        main_language="javascript"
    elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
        project_type="python"
        main_language="python"
    elif [[ -f "*.csproj" ]] || [[ -f "*.sln" ]]; then
        project_type="dotnet"
        main_language="csharp"
    elif [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then
        project_type="java"
        main_language="java"
    elif [[ -f "go.mod" ]]; then
        project_type="go"
        main_language="go"
    fi
    
    echo "$project_type:$main_language"
}

# Generate README
generate_readme() {
    local project_name="${1:-Project}"
    local description="${2:-A project built with ZeroDev}"
    
    log_event "INFO" "DOCUMENTATION" "Generating README.md"
    
    local project_info=$(detect_project)
    local project_type="${project_info%%:*}"
    local language="${project_info##*:}"
    
    cat > README.md << EOF
# $project_name

$description

## 🚀 Quick Start

### Prerequisites
EOF

    # Language-specific prerequisites
    case "$language" in
        javascript)
            cat >> README.md << 'EOF'
- Node.js 14.0 or higher
- npm or yarn

### Installation
```bash
npm install
# or
yarn install
```

### Running the Application
```bash
npm start
# or
yarn start
```

### Running Tests
```bash
npm test
# or
yarn test
```
EOF
            ;;
        python)
            cat >> README.md << 'EOF'
- Python 3.8 or higher
- pip

### Installation
```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Running the Application
```bash
python main.py
# or
python -m app
```

### Running Tests
```bash
pytest
# or
python -m pytest
```
EOF
            ;;
        csharp)
            cat >> README.md << 'EOF'
- .NET 6.0 or higher

### Installation
```bash
dotnet restore
```

### Running the Application
```bash
dotnet run
```

### Running Tests
```bash
dotnet test
```
EOF
            ;;
    esac
    
    # Add common sections
    cat >> README.md << 'EOF'

## 📁 Project Structure

```
.
├── src/            # Source code
├── tests/          # Test files
├── docs/           # Documentation
└── README.md       # This file
```

## 🛠️ Development

### Code Style
This project follows standard coding conventions for its language.

### Contributing
Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## 📚 Documentation

For more detailed documentation, see the [docs](docs/) directory.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Built with [ZeroDev](https://github.com/zerodev) - AI-powered development system

---
*Generated with ❤️ by Documentation Agent*
EOF

    log_event "SUCCESS" "DOCUMENTATION" "README.md generated"
}

# Generate API documentation
generate_api_docs() {
    local output_dir="${1:-docs/api}"
    mkdir -p "$output_dir"
    
    log_event "INFO" "DOCUMENTATION" "Generating API documentation"
    
    # Find API endpoints
    local endpoints=()
    
    # Search for Express routes (Node.js)
    if [[ -f "package.json" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ (app|router)\.(get|post|put|delete|patch)\([\'\"](/[^\'\"]*) ]]; then
                endpoints+=("${BASH_REMATCH[2]} ${BASH_REMATCH[3]}")
            fi
        done < <(find . -name "*.js" -o -name "*.ts" | xargs grep -h "app\.\|router\." 2>/dev/null || true)
    fi
    
    # Search for FastAPI routes (Python)
    if [[ -f "requirements.txt" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ @(app|router)\.(get|post|put|delete|patch)\([\"\'](/[^\"\']*) ]]; then
                endpoints+=("${BASH_REMATCH[2]} ${BASH_REMATCH[3]}")
            fi
        done < <(find . -name "*.py" | xargs grep -h "@app\.\|@router\." 2>/dev/null || true)
    fi
    
    # Generate API documentation
    cat > "$output_dir/API.md" << EOF
# API Documentation

## Endpoints

EOF

    if [[ ${#endpoints[@]} -gt 0 ]]; then
        for endpoint in "${endpoints[@]}"; do
            local method="${endpoint%% *}"
            local path="${endpoint#* }"
            cat >> "$output_dir/API.md" << EOF
### ${method^^} $path

**Description**: [Add description]

**Parameters**:
- [Add parameters]

**Request Body**:
\`\`\`json
{
  // Add request body example
}
\`\`\`

**Response**:
\`\`\`json
{
  // Add response example
}
\`\`\`

---

EOF
        done
    else
        echo "No API endpoints detected." >> "$output_dir/API.md"
    fi
    
    log_event "SUCCESS" "DOCUMENTATION" "API documentation generated at $output_dir/API.md"
}

# Generate code documentation
generate_code_docs() {
    local language="$1"
    local output_dir="${2:-docs/code}"
    mkdir -p "$output_dir"
    
    log_event "INFO" "DOCUMENTATION" "Generating code documentation for $language"
    
    case "$language" in
        javascript|typescript)
            # Use JSDoc
            if command -v jsdoc &> /dev/null; then
                jsdoc -r src -d "$output_dir"
            else
                echo "JSDoc not installed. Install with: npm install -g jsdoc"
            fi
            ;;
        python)
            # Use Sphinx or pydoc
            if command -v sphinx-build &> /dev/null; then
                sphinx-quickstart -q -p "Project" -a "Author" -v "1.0" "$output_dir"
                sphinx-apidoc -o "$output_dir" .
                sphinx-build -b html "$output_dir" "$output_dir/_build"
            else
                # Fallback to pydoc
                find . -name "*.py" -exec pydoc -w {} \; 2>/dev/null
                mv *.html "$output_dir/" 2>/dev/null || true
            fi
            ;;
        csharp)
            # Use XML documentation
            if command -v docfx &> /dev/null; then
                docfx init -q -o "$output_dir"
                docfx build "$output_dir/docfx.json"
            else
                echo "DocFX not installed. Install from: https://dotnet.github.io/docfx/"
            fi
            ;;
    esac
    
    log_event "SUCCESS" "DOCUMENTATION" "Code documentation generated"
}

# Generate user guide
generate_user_guide() {
    local output_file="${1:-docs/USER_GUIDE.md}"
    mkdir -p "$(dirname "$output_file")"
    
    log_event "INFO" "DOCUMENTATION" "Generating user guide"
    
    cat > "$output_file" << 'EOF'
# User Guide

## Table of Contents
1. [Getting Started](#getting-started)
2. [Features](#features)
3. [Configuration](#configuration)
4. [Troubleshooting](#troubleshooting)
5. [FAQ](#faq)

## Getting Started

### Installation
Follow the installation instructions in the [README](../README.md).

### First Steps
1. Configure your environment
2. Run the application
3. Access the interface

## Features

### Feature 1
[Description of feature 1]

### Feature 2
[Description of feature 2]

## Configuration

### Environment Variables
| Variable | Description | Default |
|----------|-------------|---------|
| PORT | Application port | 3000 |
| DEBUG | Debug mode | false |

### Configuration Files
- `config.json` - Main configuration
- `.env` - Environment variables

## Troubleshooting

### Common Issues

#### Issue: Application won't start
**Solution**: Check that all dependencies are installed and ports are available.

#### Issue: Connection errors
**Solution**: Verify network configuration and firewall settings.

## FAQ

**Q: How do I update the application?**
A: Pull the latest changes and run the update script.

**Q: Where are logs stored?**
A: Logs are stored in the `logs/` directory.

---
*Generated by Documentation Agent*
EOF

    log_event "SUCCESS" "DOCUMENTATION" "User guide generated at $output_file"
}

# Update changelog
update_changelog() {
    local version="${1:-1.0.0}"
    local changes="${2:-Various improvements}"
    local changelog_file="CHANGELOG.md"
    
    log_event "INFO" "DOCUMENTATION" "Updating changelog"
    
    # Create changelog if it doesn't exist
    if [[ ! -f "$changelog_file" ]]; then
        cat > "$changelog_file" << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
    fi
    
    # Add new entry
    local date=$(date +%Y-%m-%d)
    local temp_file=$(mktemp)
    
    # Extract header
    head -n 6 "$changelog_file" > "$temp_file"
    
    # Add new version
    cat >> "$temp_file" << EOF

## [$version] - $date

### Added
- $changes

### Changed
- Updated documentation

### Fixed
- Various bug fixes

EOF
    
    # Add rest of file
    tail -n +7 "$changelog_file" >> "$temp_file" 2>/dev/null || true
    
    mv "$temp_file" "$changelog_file"
    
    log_event "SUCCESS" "DOCUMENTATION" "Changelog updated with version $version"
}

# Generate all documentation
generate_all() {
    echo -e "${CYAN}Generating comprehensive documentation...${NC}"
    
    local project_info=$(detect_project)
    local language="${project_info##*:}"
    
    # Generate README
    generate_readme "My Project" "An awesome project built with ZeroDev"
    
    # Generate API docs
    generate_api_docs
    
    # Generate code docs
    generate_code_docs "$language"
    
    # Generate user guide
    generate_user_guide
    
    # Update changelog
    update_changelog "1.0.0" "Initial release"
    
    # Create documentation index
    cat > docs/index.md << 'EOF'
# Documentation Index

## Available Documentation

- [API Documentation](api/API.md) - REST API endpoints
- [User Guide](USER_GUIDE.md) - How to use the application
- [Code Documentation](code/) - Generated code documentation
- [Contributing](../CONTRIBUTING.md) - How to contribute

## Quick Links

- [README](../README.md)
- [Changelog](../CHANGELOG.md)
- [License](../LICENSE)

---
*Documentation generated by ZeroDev Documentation Agent*
EOF

    echo -e "${GREEN}✓ Documentation generation complete!${NC}"
}

# Main execution
main() {
    show_banner
    
    case "${1:-generate}" in
        generate)
            generate_all
            ;;
        readme)
            generate_readme "${2:-Project}" "${3:-A ZeroDev project}"
            ;;
        api)
            generate_api_docs "${2:-docs/api}"
            ;;
        code)
            local lang="${2:-$(detect_project | cut -d: -f2)}"
            generate_code_docs "$lang" "${3:-docs/code}"
            ;;
        guide)
            generate_user_guide "${2:-docs/USER_GUIDE.md}"
            ;;
        changelog)
            update_changelog "${2:-1.0.0}" "${3:-Updates and improvements}"
            ;;
        *)
            echo "Usage: $0 {generate|readme|api|code|guide|changelog} [options]"
            exit 1
            ;;
    esac
}

main "$@"
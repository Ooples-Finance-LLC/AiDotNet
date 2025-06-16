#!/bin/bash
# Project Generator Agent - Creates complete projects from descriptions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
STATE_DIR="$SCRIPT_DIR/state/project_generator"
mkdir -p "$STATE_DIR" "$TEMPLATES_DIR"

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse command line arguments
DESCRIPTION=""
OUTPUT_DIR="."
LANGUAGE="auto"
FRAMEWORK="auto"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --description)
            DESCRIPTION="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --framework)
            FRAMEWORK="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Analyze description to determine project type
analyze_description() {
    local desc="$1"
    local project_type=""
    local features=()
    
    # Detect project type
    if [[ "$desc" =~ (API|api|REST|rest|endpoint) ]]; then
        project_type="api"
        features+=("rest")
    elif [[ "$desc" =~ (web|website|frontend) ]]; then
        project_type="web"
        features+=("frontend")
    elif [[ "$desc" =~ (mobile|app|iOS|Android) ]]; then
        project_type="mobile"
        features+=("mobile")
    elif [[ "$desc" =~ (CLI|cli|command|tool) ]]; then
        project_type="cli"
        features+=("cli")
    elif [[ "$desc" =~ (library|package|module) ]]; then
        project_type="library"
        features+=("library")
    else
        project_type="fullstack"
        features+=("fullstack")
    fi
    
    # Detect features
    [[ "$desc" =~ (auth|login|user) ]] && features+=("authentication")
    [[ "$desc" =~ (database|db|data) ]] && features+=("database")
    [[ "$desc" =~ (real-time|realtime|websocket) ]] && features+=("realtime")
    [[ "$desc" =~ (payment|stripe|billing) ]] && features+=("payments")
    [[ "$desc" =~ (email|mail|notification) ]] && features+=("notifications")
    [[ "$desc" =~ (search|elasticsearch) ]] && features+=("search")
    [[ "$desc" =~ (file|upload|storage) ]] && features+=("file-storage")
    [[ "$desc" =~ (docker|container) ]] && features+=("docker")
    [[ "$desc" =~ (test|testing) ]] && features+=("testing")
    
    echo "$project_type"
    printf '%s\n' "${features[@]}"
}

# Determine best language and framework
determine_stack() {
    local project_type="$1"
    local lang="$LANGUAGE"
    local fw="$FRAMEWORK"
    
    if [[ "$lang" == "auto" ]]; then
        case "$project_type" in
            api)
                lang="javascript"
                fw="express"
                ;;
            web)
                lang="javascript"
                fw="react"
                ;;
            mobile)
                lang="javascript"
                fw="react-native"
                ;;
            cli)
                lang="python"
                fw="click"
                ;;
            library)
                lang="typescript"
                fw="none"
                ;;
            fullstack)
                lang="javascript"
                fw="nextjs"
                ;;
        esac
    fi
    
    echo "$lang:$fw"
}

# Generate project structure
generate_structure() {
    local project_type="$1"
    local stack="$2"
    local features="$3"
    
    echo -e "${CYAN}Generating project structure...${NC}"
    
    # Create base directories
    mkdir -p "$OUTPUT_DIR"/{src,tests,docs,config}
    
    # Language-specific structure
    case "${stack%%:*}" in
        javascript|typescript)
            mkdir -p "$OUTPUT_DIR"/{src/{components,services,utils},public,scripts}
            ;;
        python)
            mkdir -p "$OUTPUT_DIR"/{src/{models,views,controllers},tests/unit,docs/api}
            ;;
        java)
            mkdir -p "$OUTPUT_DIR"/src/{main/java/com/example/{controllers,models,services},test/java}
            ;;
        go)
            mkdir -p "$OUTPUT_DIR"/{cmd,internal/{handlers,models,services},pkg}
            ;;
    esac
    
    # Feature-specific directories
    for feature in $features; do
        case "$feature" in
            authentication)
                mkdir -p "$OUTPUT_DIR"/src/auth
                ;;
            database)
                mkdir -p "$OUTPUT_DIR"/{src/db,migrations}
                ;;
            realtime)
                mkdir -p "$OUTPUT_DIR"/src/websocket
                ;;
        esac
    done
}

# Generate configuration files
generate_configs() {
    local stack="$1"
    local features="$2"
    
    echo -e "${CYAN}Generating configuration files...${NC}"
    
    case "${stack%%:*}" in
        javascript|typescript)
            # package.json
            cat > "$OUTPUT_DIR/package.json" << EOF
{
  "name": "generated-project",
  "version": "1.0.0",
  "description": "$DESCRIPTION",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest",
    "build": "webpack"
  },
  "dependencies": {
    "express": "^4.18.0",
    "dotenv": "^16.0.0"
  },
  "devDependencies": {
    "nodemon": "^2.0.0",
    "jest": "^29.0.0"
  }
}
EOF
            ;;
        python)
            # requirements.txt
            cat > "$OUTPUT_DIR/requirements.txt" << EOF
fastapi==0.95.0
uvicorn==0.21.0
pydantic==1.10.0
python-dotenv==1.0.0
pytest==7.3.0
EOF
            
            # setup.py
            cat > "$OUTPUT_DIR/setup.py" << EOF
from setuptools import setup, find_packages

setup(
    name="generated-project",
    version="1.0.0",
    description="$DESCRIPTION",
    packages=find_packages(),
    python_requires=">=3.8",
)
EOF
            ;;
    esac
    
    # Common configs
    cat > "$OUTPUT_DIR/.gitignore" << 'EOF'
# Dependencies
node_modules/
venv/
__pycache__/

# Environment
.env
.env.local

# Build
dist/
build/
*.egg-info/

# IDE
.vscode/
.idea/
*.swp

# Logs
*.log
logs/

# OS
.DS_Store
Thumbs.db
EOF

    cat > "$OUTPUT_DIR/README.md" << EOF
# Generated Project

$DESCRIPTION

## Setup

\`\`\`bash
# Install dependencies
npm install  # or pip install -r requirements.txt

# Run development server
npm run dev  # or python src/main.py
\`\`\`

## Features

$(echo "$features" | sed 's/ /\n- /g' | sed 's/^/- /')

## Structure

\`\`\`
$(tree "$OUTPUT_DIR" 2>/dev/null || find "$OUTPUT_DIR" -type d | sed 's|[^/]*/|- |g')
\`\`\`

---
Generated by ZeroDev
EOF
}

# Generate source code
generate_code() {
    local project_type="$1"
    local stack="$2"
    local features="$3"
    
    echo -e "${CYAN}Generating source code...${NC}"
    
    case "$project_type" in
        api)
            generate_api_code "$stack" "$features"
            ;;
        web)
            generate_web_code "$stack" "$features"
            ;;
        cli)
            generate_cli_code "$stack" "$features"
            ;;
        *)
            generate_fullstack_code "$stack" "$features"
            ;;
    esac
}

# Generate API code
generate_api_code() {
    local stack="$1"
    local features="$2"
    
    case "${stack%%:*}" in
        javascript)
            cat > "$OUTPUT_DIR/src/index.js" << 'EOF'
const express = require('express');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.get('/', (req, res) => {
  res.json({ message: 'API is running' });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = app;
EOF
            ;;
        python)
            cat > "$OUTPUT_DIR/src/main.py" << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from dotenv import load_dotenv
import os

load_dotenv()

app = FastAPI(title="Generated API")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "API is running"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
EOF
            ;;
    esac
    
    # Add feature-specific code
    for feature in $features; do
        case "$feature" in
            authentication)
                add_auth_code "$stack"
                ;;
            database)
                add_database_code "$stack"
                ;;
        esac
    done
}

# Add authentication code
add_auth_code() {
    local stack="$1"
    
    echo -e "${CYAN}Adding authentication...${NC}"
    
    case "${stack%%:*}" in
        javascript)
            mkdir -p "$OUTPUT_DIR/src/auth"
            cat > "$OUTPUT_DIR/src/auth/auth.js" << 'EOF'
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

const generateToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: '7d',
  });
};

const verifyToken = (token) => {
  return jwt.verify(token, process.env.JWT_SECRET);
};

const hashPassword = async (password) => {
  return await bcrypt.hash(password, 10);
};

const comparePassword = async (password, hash) => {
  return await bcrypt.compare(password, hash);
};

module.exports = {
  generateToken,
  verifyToken,
  hashPassword,
  comparePassword,
};
EOF
            ;;
    esac
}

# Main execution
echo -e "${BOLD}${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║     Project Generator Agent v1.0       ║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}Analyzing project requirements...${NC}"

# Analyze description
IFS=$'\n' read -d '' -ra analysis <<< "$(analyze_description "$DESCRIPTION")"
project_type="${analysis[0]}"
features="${analysis[@]:1}"

echo -e "${GREEN}✓ Project type: $project_type${NC}"
echo -e "${GREEN}✓ Features: ${features[*]}${NC}"

# Determine stack
stack=$(determine_stack "$project_type")
echo -e "${GREEN}✓ Stack: $stack${NC}"

# Generate project
generate_structure "$project_type" "$stack" "${features[*]}"
generate_configs "$stack" "${features[*]}"
generate_code "$project_type" "$stack" "${features[*]}"

# Final steps
echo -e "\n${CYAN}Running final setup...${NC}"

# Initialize git
if command -v git &>/dev/null; then
    cd "$OUTPUT_DIR"
    git init
    git add .
    git commit -m "Initial project generated by ZeroDev"
fi

# Generate success report
cat > "$STATE_DIR/generation_report.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "description": "$DESCRIPTION",
  "project_type": "$project_type",
  "stack": "$stack",
  "features": $(printf '%s\n' "${features[@]}" | jq -R . | jq -s .),
  "output_dir": "$OUTPUT_DIR",
  "status": "success"
}
EOF

echo -e "\n${BOLD}${GREEN}✓ Project generated successfully!${NC}"
echo -e "${CYAN}Location: $OUTPUT_DIR${NC}"
echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. cd $OUTPUT_DIR"
echo -e "  2. Install dependencies"
echo -e "  3. Start development"
echo -e "\n${YELLOW}Happy coding! 🚀${NC}"
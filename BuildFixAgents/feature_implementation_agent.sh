#!/bin/bash
# Feature Implementation Agent - Adds features to existing projects

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/state/feature_implementation"
mkdir -p "$STATE_DIR"

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments
FEATURE=""
CONTEXT="auto"
INTEGRATE=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --feature)
            FEATURE="$2"
            shift 2
            ;;
        --context)
            CONTEXT="$2"
            shift 2
            ;;
        --integrate)
            INTEGRATE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Banner
echo -e "${BOLD}${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║   Feature Implementation Agent v1.0    ║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════╝${NC}"

# Analyze feature request
analyze_feature() {
    local feature="$1"
    local feature_type=""
    local components=()
    
    echo -e "\n${CYAN}Analyzing feature request...${NC}"
    
    # Detect feature type
    if [[ "$feature" =~ (auth|login|user|oauth|jwt) ]]; then
        feature_type="authentication"
        components+=("auth-service" "user-model" "auth-middleware" "auth-routes")
    elif [[ "$feature" =~ (api|endpoint|route|REST) ]]; then
        feature_type="api"
        components+=("routes" "controllers" "models" "validators")
    elif [[ "$feature" =~ (database|model|schema|migration) ]]; then
        feature_type="database"
        components+=("models" "migrations" "seeders")
    elif [[ "$feature" =~ (payment|stripe|billing|subscription) ]]; then
        feature_type="payment"
        components+=("payment-service" "billing-models" "webhook-handlers")
    elif [[ "$feature" =~ (email|notification|alert|message) ]]; then
        feature_type="notification"
        components+=("email-service" "templates" "notification-queue")
    elif [[ "$feature" =~ (search|elasticsearch|filter) ]]; then
        feature_type="search"
        components+=("search-service" "indexers" "search-api")
    elif [[ "$feature" =~ (file|upload|storage|image) ]]; then
        feature_type="file-storage"
        components+=("upload-handler" "storage-service" "file-models")
    elif [[ "$feature" =~ (cache|redis|performance) ]]; then
        feature_type="caching"
        components+=("cache-service" "cache-middleware")
    elif [[ "$feature" =~ (test|testing|unit|integration) ]]; then
        feature_type="testing"
        components+=("test-suite" "fixtures" "mocks")
    else
        feature_type="generic"
        components+=("service" "controller" "routes")
    fi
    
    echo "$feature_type"
    printf '%s\n' "${components[@]}"
}

# Detect existing project structure
analyze_project_structure() {
    local structure=""
    
    echo -e "\n${CYAN}Analyzing project structure...${NC}"
    
    # Check for common patterns
    if [[ -d "src" ]]; then
        structure="src"
    elif [[ -d "app" ]]; then
        structure="app"
    elif [[ -d "lib" ]]; then
        structure="lib"
    else
        structure="root"
    fi
    
    # Detect patterns
    local has_controllers=false
    local has_services=false
    local has_models=false
    
    [[ -d "*/controllers" ]] || [[ -d "*/controller" ]] && has_controllers=true
    [[ -d "*/services" ]] || [[ -d "*/service" ]] && has_services=true
    [[ -d "*/models" ]] || [[ -d "*/model" ]] && has_models=true
    
    echo "$structure:$has_controllers:$has_services:$has_models"
}

# Generate authentication feature
implement_authentication() {
    local context="$1"
    
    echo -e "\n${YELLOW}Implementing authentication feature...${NC}"
    
    case "$context" in
        node)
            implement_node_auth
            ;;
        python)
            implement_python_auth
            ;;
        dotnet)
            implement_dotnet_auth
            ;;
        *)
            echo -e "${RED}Unsupported context for authentication: $context${NC}"
            return 1
            ;;
    esac
}

# Node.js authentication implementation
implement_node_auth() {
    echo -e "${CYAN}Adding authentication to Node.js project...${NC}"
    
    # Create auth directory
    mkdir -p src/auth
    
    # Auth service
    cat > src/auth/authService.js << 'EOF'
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

class AuthService {
  constructor() {
    this.JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
    this.JWT_EXPIRY = process.env.JWT_EXPIRY || '7d';
  }

  async hashPassword(password) {
    return await bcrypt.hash(password, 10);
  }

  async verifyPassword(password, hash) {
    return await bcrypt.compare(password, hash);
  }

  generateToken(userId, email) {
    return jwt.sign(
      { userId, email },
      this.JWT_SECRET,
      { expiresIn: this.JWT_EXPIRY }
    );
  }

  verifyToken(token) {
    try {
      return jwt.verify(token, this.JWT_SECRET);
    } catch (error) {
      throw new Error('Invalid token');
    }
  }

  extractToken(authHeader) {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new Error('No token provided');
    }
    return authHeader.substring(7);
  }
}

module.exports = new AuthService();
EOF

    # Auth middleware
    cat > src/auth/authMiddleware.js << 'EOF'
const authService = require('./authService');

const authMiddleware = async (req, res, next) => {
  try {
    const token = authService.extractToken(req.headers.authorization);
    const decoded = authService.verifyToken(token);
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Unauthorized' });
  }
};

const optionalAuth = async (req, res, next) => {
  try {
    const token = authService.extractToken(req.headers.authorization);
    const decoded = authService.verifyToken(token);
    req.user = decoded;
  } catch (error) {
    req.user = null;
  }
  next();
};

module.exports = { authMiddleware, optionalAuth };
EOF

    # Auth routes
    cat > src/auth/authRoutes.js << 'EOF'
const express = require('express');
const router = express.Router();
const authService = require('./authService');
const { authMiddleware } = require('./authMiddleware');

// Register
router.post('/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;
    
    // TODO: Add validation and user creation logic
    const hashedPassword = await authService.hashPassword(password);
    
    // Create user in database
    const user = {
      id: Date.now(), // Replace with actual DB operation
      email,
      name,
      password: hashedPassword
    };
    
    const token = authService.generateToken(user.id, user.email);
    
    res.status(201).json({
      message: 'User created successfully',
      token,
      user: { id: user.id, email: user.email, name: user.name }
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    // TODO: Fetch user from database
    const user = null; // Replace with actual DB query
    
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const isValid = await authService.verifyPassword(password, user.password);
    if (!isValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const token = authService.generateToken(user.id, user.email);
    
    res.json({
      message: 'Login successful',
      token,
      user: { id: user.id, email: user.email, name: user.name }
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Get current user
router.get('/me', authMiddleware, async (req, res) => {
  try {
    // TODO: Fetch full user details from database
    res.json({ user: req.user });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

module.exports = router;
EOF

    # Update package.json dependencies
    if [[ -f "package.json" ]]; then
        echo -e "${CYAN}Updating dependencies...${NC}"
        npm install jsonwebtoken bcryptjs
    fi
    
    echo -e "${GREEN}✓ Authentication feature implemented${NC}"
}

# Generate API endpoints
implement_api_endpoints() {
    local context="$1"
    local api_desc="$2"
    
    echo -e "\n${YELLOW}Implementing API endpoints...${NC}"
    
    # Parse API description
    local resource=$(echo "$api_desc" | grep -oE "(user|product|order|post|item|task)" | head -1)
    [[ -z "$resource" ]] && resource="resource"
    
    case "$context" in
        node)
            implement_node_api "$resource"
            ;;
        python)
            implement_python_api "$resource"
            ;;
        *)
            echo -e "${RED}Unsupported context for API: $context${NC}"
            return 1
            ;;
    esac
}

# Node.js API implementation
implement_node_api() {
    local resource="$1"
    local resource_plural="${resource}s"
    
    echo -e "${CYAN}Creating REST API for $resource...${NC}"
    
    mkdir -p src/{routes,controllers,models}
    
    # Model
    cat > "src/models/${resource}.js" << EOF
class ${resource^} {
  constructor(data = {}) {
    this.id = data.id || null;
    this.name = data.name || '';
    this.description = data.description || '';
    this.createdAt = data.createdAt || new Date();
    this.updatedAt = data.updatedAt || new Date();
  }

  validate() {
    const errors = [];
    if (!this.name) errors.push('Name is required');
    return errors;
  }

  toJSON() {
    return {
      id: this.id,
      name: this.name,
      description: this.description,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt
    };
  }
}

module.exports = ${resource^};
EOF

    # Controller
    cat > "src/controllers/${resource}Controller.js" << EOF
const ${resource^} = require('../models/${resource}');

class ${resource^}Controller {
  // GET all ${resource_plural}
  async getAll(req, res) {
    try {
      // TODO: Implement database query
      const ${resource_plural} = [];
      res.json({ ${resource_plural} });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  // GET single ${resource}
  async getOne(req, res) {
    try {
      const { id } = req.params;
      // TODO: Implement database query
      const ${resource} = null;
      
      if (!${resource}) {
        return res.status(404).json({ error: '${resource^} not found' });
      }
      
      res.json({ ${resource} });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  // POST create ${resource}
  async create(req, res) {
    try {
      const ${resource} = new ${resource^}(req.body);
      const errors = ${resource}.validate();
      
      if (errors.length > 0) {
        return res.status(400).json({ errors });
      }
      
      // TODO: Save to database
      ${resource}.id = Date.now();
      
      res.status(201).json({ ${resource}: ${resource}.toJSON() });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  // PUT update ${resource}
  async update(req, res) {
    try {
      const { id } = req.params;
      // TODO: Implement database update
      
      res.json({ message: '${resource^} updated successfully' });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  // DELETE ${resource}
  async delete(req, res) {
    try {
      const { id } = req.params;
      // TODO: Implement database delete
      
      res.json({ message: '${resource^} deleted successfully' });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
}

module.exports = new ${resource^}Controller();
EOF

    # Routes
    cat > "src/routes/${resource}Routes.js" << EOF
const express = require('express');
const router = express.Router();
const ${resource}Controller = require('../controllers/${resource}Controller');

// Define routes
router.get('/', ${resource}Controller.getAll);
router.get('/:id', ${resource}Controller.getOne);
router.post('/', ${resource}Controller.create);
router.put('/:id', ${resource}Controller.update);
router.delete('/:id', ${resource}Controller.delete);

module.exports = router;
EOF

    echo -e "${GREEN}✓ REST API for $resource implemented${NC}"
}

# Main feature implementation
implement_feature() {
    local feature_type="$1"
    local context="$2"
    
    case "$feature_type" in
        authentication)
            implement_authentication "$context"
            ;;
        api)
            implement_api_endpoints "$context" "$FEATURE"
            ;;
        database)
            implement_database_feature "$context"
            ;;
        payment)
            implement_payment_feature "$context"
            ;;
        notification)
            implement_notification_feature "$context"
            ;;
        search)
            implement_search_feature "$context"
            ;;
        file-storage)
            implement_file_storage "$context"
            ;;
        testing)
            implement_testing_suite "$context"
            ;;
        *)
            echo -e "${YELLOW}Implementing generic feature...${NC}"
            implement_generic_feature "$context"
            ;;
    esac
}

# Integration helper
integrate_feature() {
    local feature_type="$1"
    local context="$2"
    
    echo -e "\n${CYAN}Integrating feature into existing codebase...${NC}"
    
    # Find main application file
    local main_file=""
    if [[ -f "src/index.js" ]]; then
        main_file="src/index.js"
    elif [[ -f "src/app.js" ]]; then
        main_file="src/app.js"
    elif [[ -f "index.js" ]]; then
        main_file="index.js"
    elif [[ -f "app.js" ]]; then
        main_file="app.js"
    fi
    
    if [[ -n "$main_file" ]]; then
        echo -e "${CYAN}Updating $main_file...${NC}"
        
        # Add integration code based on feature type
        case "$feature_type" in
            authentication)
                echo -e "\n${YELLOW}Add the following to your main file:${NC}"
                cat << 'EOF'

// Authentication
const authRoutes = require('./src/auth/authRoutes');
app.use('/api/auth', authRoutes);
EOF
                ;;
            api)
                local resource=$(echo "$FEATURE" | grep -oE "(user|product|order|post|item|task)" | head -1)
                [[ -z "$resource" ]] && resource="resource"
                echo -e "\n${YELLOW}Add the following to your main file:${NC}"
                cat << EOF

// ${resource^} API
const ${resource}Routes = require('./src/routes/${resource}Routes');
app.use('/api/${resource}s', ${resource}Routes);
EOF
                ;;
        esac
    fi
    
    echo -e "${GREEN}✓ Integration instructions provided${NC}"
}

# Execute feature implementation
echo -e "\n${CYAN}Feature: $FEATURE${NC}"
echo -e "${CYAN}Context: $CONTEXT${NC}"

# Analyze feature
IFS=$'\n' read -d '' -ra analysis <<< "$(analyze_feature "$FEATURE")"
feature_type="${analysis[0]}"
components=("${analysis[@]:1}")

echo -e "${GREEN}✓ Feature type: $feature_type${NC}"
echo -e "${GREEN}✓ Components: ${components[*]}${NC}"

# Analyze project
project_structure=$(analyze_project_structure)
echo -e "${GREEN}✓ Project structure: $project_structure${NC}"

# Implement feature
implement_feature "$feature_type" "$CONTEXT"

# Integrate if requested
if [[ "$INTEGRATE" == "true" ]]; then
    integrate_feature "$feature_type" "$CONTEXT"
fi

# Save state
cat > "$STATE_DIR/implementation_report.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "feature": "$FEATURE",
  "feature_type": "$feature_type",
  "context": "$CONTEXT",
  "components": $(printf '%s\n' "${components[@]}" | jq -R . | jq -s .),
  "integrated": $INTEGRATE,
  "status": "success"
}
EOF

echo -e "\n${BOLD}${GREEN}✓ Feature implementation complete!${NC}"
echo -e "${CYAN}Don't forget to:${NC}"
echo -e "  1. Install any new dependencies"
echo -e "  2. Update your database schema if needed"
echo -e "  3. Add environment variables"
echo -e "  4. Write tests for the new feature"
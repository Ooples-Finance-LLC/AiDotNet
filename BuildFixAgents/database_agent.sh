#!/bin/bash
# Database Agent - Handles database operations, migrations, and optimization
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_STATE="$SCRIPT_DIR/state/database"
mkdir -p "$DB_STATE/migrations" "$DB_STATE/schemas"

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
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}║        Database Agent v1.0             ║${NC}"
    echo -e "${BOLD}${YELLOW}╚════════════════════════════════════════╝${NC}"
}

# Detect database type from project
detect_database() {
    local db_type="sqlite"  # Default
    
    # Check for database configurations
    if grep -q "mongodb\|mongoose" package.json 2>/dev/null; then
        db_type="mongodb"
    elif grep -q "pg\|postgres" package.json 2>/dev/null || grep -q "psycopg" requirements.txt 2>/dev/null; then
        db_type="postgresql"
    elif grep -q "mysql\|mysql2" package.json 2>/dev/null || grep -q "pymysql" requirements.txt 2>/dev/null; then
        db_type="mysql"
    elif grep -q "mssql\|tedious" package.json 2>/dev/null; then
        db_type="mssql"
    elif grep -q "redis" package.json 2>/dev/null || grep -q "redis" requirements.txt 2>/dev/null; then
        db_type="redis"
    fi
    
    echo "$db_type"
}

# Generate database schema
generate_schema() {
    local db_type="${1:-$(detect_database)}"
    local schema_name="${2:-main}"
    local tables="${3:-users,posts}"
    
    log_event "INFO" "DATABASE" "Generating schema for $db_type"
    
    case "$db_type" in
        postgresql|mysql)
            generate_sql_schema "$db_type" "$schema_name" "$tables"
            ;;
        mongodb)
            generate_mongo_schema "$schema_name" "$tables"
            ;;
        sqlite)
            generate_sqlite_schema "$schema_name" "$tables"
            ;;
        *)
            log_event "ERROR" "DATABASE" "Unsupported database type: $db_type"
            return 1
            ;;
    esac
}

# Generate SQL schema
generate_sql_schema() {
    local db_type="$1"
    local schema_name="$2"
    local tables="$3"
    
    local schema_file="$DB_STATE/schemas/${schema_name}_schema.sql"
    
    cat > "$schema_file" << EOF
-- Schema for $schema_name
-- Database: $db_type
-- Generated: $(date)

EOF

    # Generate common tables
    if [[ "$tables" == *"users"* ]]; then
        cat >> "$schema_file" << 'EOF'
-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_created_at ON users(created_at);

EOF
    fi
    
    if [[ "$tables" == *"posts"* ]]; then
        cat >> "$schema_file" << 'EOF'
-- Posts table
CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    status VARCHAR(50) DEFAULT 'draft',
    published_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_published_at ON posts(published_at);

EOF
    fi
    
    # Add update trigger for updated_at
    if [[ "$db_type" == "postgresql" ]]; then
        cat >> "$schema_file" << 'EOF'
-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EOF
    fi
    
    log_event "SUCCESS" "DATABASE" "SQL schema generated at $schema_file"
}

# Generate MongoDB schema
generate_mongo_schema() {
    local schema_name="$1"
    local collections="$2"
    
    local schema_file="$DB_STATE/schemas/${schema_name}_schema.js"
    
    cat > "$schema_file" << 'EOF'
// MongoDB Schema Definitions
const mongoose = require('mongoose');

EOF

    if [[ "$collections" == *"users"* ]]; then
        cat >> "$schema_file" << 'EOF'
// User Schema
const userSchema = new mongoose.Schema({
    email: {
        type: String,
        required: true,
        unique: true,
        lowercase: true,
        trim: true
    },
    username: {
        type: String,
        required: true,
        unique: true,
        trim: true
    },
    password: {
        type: String,
        required: true
    },
    profile: {
        firstName: String,
        lastName: String,
        avatar: String
    },
    isActive: {
        type: Boolean,
        default: true
    },
    lastLogin: Date
}, {
    timestamps: true
});

// Indexes
userSchema.index({ email: 1 });
userSchema.index({ username: 1 });
userSchema.index({ createdAt: -1 });

const User = mongoose.model('User', userSchema);

EOF
    fi
    
    if [[ "$collections" == *"posts"* ]]; then
        cat >> "$schema_file" << 'EOF'
// Post Schema
const postSchema = new mongoose.Schema({
    author: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    title: {
        type: String,
        required: true,
        trim: true
    },
    content: String,
    tags: [String],
    status: {
        type: String,
        enum: ['draft', 'published', 'archived'],
        default: 'draft'
    },
    publishedAt: Date,
    views: {
        type: Number,
        default: 0
    }
}, {
    timestamps: true
});

// Indexes
postSchema.index({ author: 1, createdAt: -1 });
postSchema.index({ status: 1, publishedAt: -1 });
postSchema.index({ tags: 1 });

const Post = mongoose.model('Post', postSchema);

module.exports = { User, Post };
EOF
    fi
    
    log_event "SUCCESS" "DATABASE" "MongoDB schema generated at $schema_file"
}

# Generate migration
generate_migration() {
    local name="$1"
    local db_type="${2:-$(detect_database)}"
    local timestamp=$(date +%Y%m%d%H%M%S)
    local migration_file="$DB_STATE/migrations/${timestamp}_${name}.sql"
    
    log_event "INFO" "DATABASE" "Generating migration: $name"
    
    cat > "$migration_file" << EOF
-- Migration: $name
-- Created: $(date)
-- Database: $db_type

-- UP Migration
BEGIN;

-- Add your migration SQL here
-- Example:
-- ALTER TABLE users ADD COLUMN phone VARCHAR(20);

COMMIT;

-- DOWN Migration (Rollback)
-- BEGIN;
-- ALTER TABLE users DROP COLUMN phone;
-- COMMIT;
EOF

    log_event "SUCCESS" "DATABASE" "Migration generated at $migration_file"
}

# Generate database connection code
generate_connection() {
    local db_type="${1:-$(detect_database)}"
    local language="${2:-javascript}"
    local output_file="${3:-db_connection}"
    
    log_event "INFO" "DATABASE" "Generating connection code for $db_type in $language"
    
    case "$language" in
        javascript)
            generate_js_connection "$db_type" "$output_file.js"
            ;;
        python)
            generate_python_connection "$db_type" "$output_file.py"
            ;;
        csharp)
            generate_csharp_connection "$db_type" "$output_file.cs"
            ;;
        *)
            log_event "ERROR" "DATABASE" "Unsupported language: $language"
            return 1
            ;;
    esac
}

# Generate JavaScript database connection
generate_js_connection() {
    local db_type="$1"
    local output_file="$2"
    
    case "$db_type" in
        postgresql)
            cat > "$output_file" << 'EOF'
const { Pool } = require('pg');

const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'myapp',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'password',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Test connection
pool.on('connect', () => {
    console.log('Connected to PostgreSQL database');
});

pool.on('error', (err) => {
    console.error('Unexpected error on idle client', err);
    process.exit(-1);
});

module.exports = {
    query: (text, params) => pool.query(text, params),
    pool
};
EOF
            ;;
        mongodb)
            cat > "$output_file" << 'EOF'
const mongoose = require('mongoose');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/myapp';

const connectDB = async () => {
    try {
        await mongoose.connect(MONGODB_URI, {
            useNewUrlParser: true,
            useUnifiedTopology: true,
        });
        console.log('Connected to MongoDB');
    } catch (error) {
        console.error('MongoDB connection error:', error);
        process.exit(1);
    }
};

// Connection events
mongoose.connection.on('error', (err) => {
    console.error('MongoDB error:', err);
});

mongoose.connection.on('disconnected', () => {
    console.log('MongoDB disconnected');
});

module.exports = { connectDB, mongoose };
EOF
            ;;
        mysql)
            cat > "$output_file" << 'EOF'
const mysql = require('mysql2');

const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'password',
    database: process.env.DB_NAME || 'myapp',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

const promisePool = pool.promise();

module.exports = {
    query: async (sql, params) => {
        const [rows] = await promisePool.execute(sql, params);
        return rows;
    },
    pool: promisePool
};
EOF
            ;;
    esac
    
    log_event "SUCCESS" "DATABASE" "Connection code generated at $output_file"
}

# Optimize queries
optimize_queries() {
    local query_file="${1:-queries.sql}"
    
    log_event "INFO" "DATABASE" "Analyzing queries for optimization"
    
    # Common optimization suggestions
    cat > "$DB_STATE/optimization_report.md" << 'EOF'
# Database Optimization Report

## Query Optimization Tips

### 1. Use Indexes
- Create indexes on columns used in WHERE clauses
- Consider composite indexes for multi-column queries
- Monitor index usage and remove unused indexes

### 2. Query Optimization
- Use EXPLAIN to analyze query execution plans
- Avoid SELECT * - specify only needed columns
- Use JOINs instead of subqueries when possible
- Limit result sets with LIMIT/OFFSET

### 3. Connection Pooling
- Implement connection pooling to reduce overhead
- Set appropriate pool sizes based on load
- Monitor connection usage

### 4. Caching
- Implement query result caching for frequently accessed data
- Use Redis or Memcached for application-level caching
- Set appropriate TTL values

### 5. Database Maintenance
- Regular VACUUM (PostgreSQL)
- ANALYZE tables to update statistics
- Monitor and optimize slow queries
- Regular backups

## Recommended Actions
1. Add indexes to foreign key columns
2. Implement query result caching
3. Set up monitoring for slow queries
4. Configure connection pooling
EOF

    log_event "SUCCESS" "DATABASE" "Optimization report generated"
}

# Generate seed data
generate_seeds() {
    local db_type="${1:-$(detect_database)}"
    local output_file="$DB_STATE/seeds/seed_data.sql"
    mkdir -p "$DB_STATE/seeds"
    
    log_event "INFO" "DATABASE" "Generating seed data"
    
    cat > "$output_file" << 'EOF'
-- Seed Data
-- Generated: $(date)

-- Insert sample users
INSERT INTO users (email, username, password_hash, first_name, last_name) VALUES
('admin@example.com', 'admin', '$2b$10$YourHashHere', 'Admin', 'User'),
('user1@example.com', 'user1', '$2b$10$YourHashHere', 'John', 'Doe'),
('user2@example.com', 'user2', '$2b$10$YourHashHere', 'Jane', 'Smith');

-- Insert sample posts
INSERT INTO posts (user_id, title, content, status, published_at) VALUES
(1, 'Welcome to Our Platform', 'This is the first post on our platform!', 'published', CURRENT_TIMESTAMP),
(2, 'Getting Started Guide', 'Here is how to get started...', 'published', CURRENT_TIMESTAMP),
(1, 'Draft Post', 'This is a draft post', 'draft', NULL);

-- Add more seed data as needed
EOF

    log_event "SUCCESS" "DATABASE" "Seed data generated at $output_file"
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        schema)
            generate_schema "${2:-}" "${3:-main}" "${4:-users,posts}"
            ;;
        migration)
            generate_migration "${2:-new_migration}"
            ;;
        connection)
            generate_connection "${2:-}" "${3:-javascript}" "${4:-db_connection}"
            ;;
        optimize)
            optimize_queries "${2:-}"
            ;;
        seed)
            generate_seeds "${2:-}"
            ;;
        init)
            echo -e "${CYAN}Initializing database setup...${NC}"
            local db_type=$(detect_database)
            echo -e "${GREEN}Detected database: $db_type${NC}"
            generate_schema "$db_type"
            generate_connection "$db_type"
            generate_seeds "$db_type"
            echo -e "${GREEN}✓ Database initialization complete!${NC}"
            ;;
        *)
            echo "Usage: $0 {schema|migration|connection|optimize|seed|init} [options]"
            echo ""
            echo "Commands:"
            echo "  schema [db_type] [name] [tables]  - Generate database schema"
            echo "  migration [name]                   - Generate migration file"
            echo "  connection [db_type] [lang] [file] - Generate connection code"
            echo "  optimize [query_file]              - Analyze and optimize queries"
            echo "  seed [db_type]                     - Generate seed data"
            echo "  init                               - Initialize complete database setup"
            exit 1
            ;;
    esac
}

main "$@"
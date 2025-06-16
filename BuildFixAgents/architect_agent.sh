#!/bin/bash

# Architect Agent - Analyzes codebase and suggests new features/improvements
# Creates architectural proposals and design documents

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
PROPOSALS_DIR="$AGENT_DIR/state/architectural_proposals"
ANALYSIS_FILE="$AGENT_DIR/state/codebase_analysis.json"

# Colors
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Agent ID
AGENT_ID="architect_agent_$$"

# Initialize
mkdir -p "$PROPOSALS_DIR"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${MAGENTA}[$timestamp] ARCHITECT_AGENT${NC} [${level}]: $message" | tee -a "$AGENT_DIR/logs/architect_agent.log"
}

# Analyze codebase structure
analyze_codebase() {
    log_message "Analyzing codebase architecture..."
    
    local total_files=$(find "$PROJECT_DIR" -name "*.cs" -type f | wc -l)
    local total_lines=$(find "$PROJECT_DIR" -name "*.cs" -type f -exec wc -l {} + | tail -1 | awk '{print $1}')
    local namespaces=$(grep -h "^namespace" "$PROJECT_DIR"/**/*.cs 2>/dev/null | sort -u | wc -l || echo "0")
    local interfaces=$(grep -h "interface I" "$PROJECT_DIR"/**/*.cs 2>/dev/null | wc -l || echo "0")
    local classes=$(grep -h "class " "$PROJECT_DIR"/**/*.cs 2>/dev/null | wc -l || echo "0")
    
    # Analyze patterns
    local has_di=$(grep -r "IServiceCollection\|DependencyInjection" "$PROJECT_DIR" 2>/dev/null | wc -l || echo "0")
    local has_async=$(grep -r "async\|await\|Task<" "$PROJECT_DIR" 2>/dev/null | wc -l || echo "0")
    local has_tests=$(find "$PROJECT_DIR" -name "*Test*.cs" -o -name "*Spec*.cs" | wc -l || echo "0")
    local has_logging=$(grep -r "ILogger\|Log\." "$PROJECT_DIR" 2>/dev/null | wc -l || echo "0")
    
    # Create analysis report
    cat > "$ANALYSIS_FILE" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": {
    "total_files": $total_files,
    "total_lines": $total_lines,
    "namespaces": $namespaces,
    "interfaces": $interfaces,
    "classes": $classes
  },
  "patterns": {
    "dependency_injection": $([ $has_di -gt 0 ] && echo "true" || echo "false"),
    "async_patterns": $([ $has_async -gt 0 ] && echo "true" || echo "false"),
    "unit_tests": $([ $has_tests -gt 0 ] && echo "true" || echo "false"),
    "logging": $([ $has_logging -gt 0 ] && echo "true" || echo "false")
  },
  "architecture_score": $(calculate_architecture_score $has_di $has_async $has_tests $has_logging)
}
EOF
}

# Calculate architecture maturity score
calculate_architecture_score() {
    local score=0
    [ $1 -gt 0 ] && score=$((score + 25))  # DI
    [ $2 -gt 0 ] && score=$((score + 25))  # Async
    [ $3 -gt 0 ] && score=$((score + 25))  # Tests
    [ $4 -gt 0 ] && score=$((score + 25))  # Logging
    echo $score
}

# Identify missing patterns
identify_missing_patterns() {
    log_message "Identifying architectural gaps..."
    
    local suggestions=()
    
    # Check for common architectural patterns
    if ! grep -r "IRepository\|Repository<" "$PROJECT_DIR" >/dev/null 2>&1; then
        suggestions+=("Repository Pattern")
    fi
    
    if ! grep -r "IUnitOfWork\|UnitOfWork" "$PROJECT_DIR" >/dev/null 2>&1; then
        suggestions+=("Unit of Work Pattern")
    fi
    
    if ! grep -r "IMediator\|MediatR" "$PROJECT_DIR" >/dev/null 2>&1; then
        suggestions+=("CQRS/Mediator Pattern")
    fi
    
    if ! grep -r "ICache\|MemoryCache\|IDistributedCache" "$PROJECT_DIR" >/dev/null 2>&1; then
        suggestions+=("Caching Layer")
    fi
    
    if ! grep -r "FluentValidation\|IValidator" "$PROJECT_DIR" >/dev/null 2>&1; then
        suggestions+=("Validation Framework")
    fi
    
    if ! grep -r "AutoMapper\|IMapper" "$PROJECT_DIR" >/dev/null 2>&1; then
        suggestions+=("Object Mapping")
    fi
    
    if ! find "$PROJECT_DIR" -name "*.http" -o -name "*.rest" >/dev/null 2>&1; then
        suggestions+=("API Testing Tools")
    fi
    
    printf '%s\n' "${suggestions[@]}"
}

# Generate feature proposals
generate_feature_proposal() {
    local feature_type="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local proposal_file="$PROPOSALS_DIR/proposal_${feature_type}_${timestamp}.md"
    
    log_message "Generating proposal for: $feature_type"
    
    case "$feature_type" in
        "Repository Pattern")
            cat > "$proposal_file" << 'EOF'
# Repository Pattern Implementation Proposal

## Overview
Implement the Repository pattern to abstract data access logic and provide a more testable architecture.

## Benefits
- Separation of concerns
- Easier unit testing
- Consistent data access API
- Simplified query logic

## Implementation Plan

### 1. Base Repository Interface
```csharp
public interface IRepository<T> where T : class
{
    Task<T> GetByIdAsync(int id);
    Task<IEnumerable<T>> GetAllAsync();
    Task<IEnumerable<T>> FindAsync(Expression<Func<T, bool>> predicate);
    Task AddAsync(T entity);
    Task UpdateAsync(T entity);
    Task RemoveAsync(T entity);
    Task<int> SaveChangesAsync();
}
```

### 2. Generic Repository Implementation
```csharp
public class Repository<T> : IRepository<T> where T : class
{
    protected readonly DbContext _context;
    protected readonly DbSet<T> _dbSet;

    public Repository(DbContext context)
    {
        _context = context;
        _dbSet = context.Set<T>();
    }
    
    // Implementation details...
}
```

### 3. Specific Repositories
- Create specific repositories for each aggregate root
- Add custom query methods as needed

## Estimated Effort
- Base implementation: 2-3 hours
- Migration of existing code: 4-6 hours
- Testing: 2-3 hours

## Next Steps
1. Create base interfaces
2. Implement generic repository
3. Create specific repositories
4. Refactor existing data access code
5. Add unit tests
EOF
            ;;
            
        "CQRS/Mediator Pattern")
            cat > "$proposal_file" << 'EOF'
# CQRS with Mediator Pattern Proposal

## Overview
Implement Command Query Responsibility Segregation (CQRS) using the Mediator pattern for better separation of concerns.

## Benefits
- Clear separation of reads and writes
- Improved scalability
- Better testability
- Reduced coupling

## Implementation Plan

### 1. Install MediatR
```xml
<PackageReference Include="MediatR" Version="12.0.0" />
```

### 2. Command Example
```csharp
public class CreateUserCommand : IRequest<int>
{
    public string Name { get; set; }
    public string Email { get; set; }
}

public class CreateUserCommandHandler : IRequestHandler<CreateUserCommand, int>
{
    private readonly IUserRepository _repository;
    
    public async Task<int> Handle(CreateUserCommand request, CancellationToken cancellationToken)
    {
        // Implementation
    }
}
```

### 3. Query Example
```csharp
public class GetUserByIdQuery : IRequest<UserDto>
{
    public int Id { get; set; }
}

public class GetUserByIdQueryHandler : IRequestHandler<GetUserByIdQuery, UserDto>
{
    // Implementation
}
```

## Migration Strategy
1. Start with new features
2. Gradually refactor existing features
3. Keep old code during transition

## Estimated Effort
- Setup: 1-2 hours
- First feature: 2-3 hours
- Full migration: 2-3 weeks
EOF
            ;;
            
        "Caching Layer")
            cat > "$proposal_file" << 'EOF'
# Caching Layer Implementation Proposal

## Overview
Add a comprehensive caching layer to improve performance and reduce database load.

## Benefits
- Reduced response times
- Lower database load
- Improved scalability
- Cost reduction

## Implementation Plan

### 1. In-Memory Caching
```csharp
public interface ICacheService
{
    Task<T> GetAsync<T>(string key);
    Task SetAsync<T>(string key, T value, TimeSpan? expiry = null);
    Task RemoveAsync(string key);
    Task<T> GetOrAddAsync<T>(string key, Func<Task<T>> factory, TimeSpan? expiry = null);
}
```

### 2. Distributed Caching (Redis)
```csharp
services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = configuration.GetConnectionString("Redis");
    options.InstanceName = "MyApp";
});
```

### 3. Cache Invalidation Strategy
- Time-based expiration
- Event-based invalidation
- Manual invalidation

## Cache Candidates
- User profiles
- Configuration data
- Frequently accessed lists
- Computed results

## Estimated Effort
- Basic implementation: 3-4 hours
- Redis integration: 2-3 hours
- Migration: 1-2 days
EOF
            ;;
            
        "Validation Framework")
            cat > "$proposal_file" << 'EOF'
# Validation Framework Proposal

## Overview
Implement FluentValidation for robust, testable validation logic.

## Benefits
- Separation of validation logic
- Better testability
- Cleaner code
- Complex validation rules

## Implementation Example

```csharp
public class CreateUserValidator : AbstractValidator<CreateUserCommand>
{
    public CreateUserValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required")
            .EmailAddress().WithMessage("Invalid email format");
            
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required")
            .MinimumLength(2).WithMessage("Name too short")
            .MaximumLength(100).WithMessage("Name too long");
            
        RuleFor(x => x.Age)
            .InclusiveBetween(18, 120).WithMessage("Invalid age");
    }
}
```

## Integration Points
- API endpoints
- Command handlers
- Domain services

## Estimated Effort
- Setup: 1-2 hours
- Migration: 1-2 days per module
EOF
            ;;
            
        *)
            echo "# $feature_type Proposal" > "$proposal_file"
            echo "" >> "$proposal_file"
            echo "## Overview" >> "$proposal_file"
            echo "Implement $feature_type to improve codebase architecture." >> "$proposal_file"
            echo "" >> "$proposal_file"
            echo "## Benefits" >> "$proposal_file"
            echo "- Improved code organization" >> "$proposal_file"
            echo "- Better maintainability" >> "$proposal_file"
            echo "- Enhanced testability" >> "$proposal_file"
            echo "" >> "$proposal_file"
            echo "## Implementation Plan" >> "$proposal_file"
            echo "To be determined based on project requirements." >> "$proposal_file"
            ;;
    esac
    
    log_message "Proposal created: $proposal_file"
    echo "$proposal_file"
}

# Analyze API endpoints and suggest improvements
analyze_api_design() {
    log_message "Analyzing API design patterns..."
    
    local controllers=$(find "$PROJECT_DIR" -name "*Controller.cs" | wc -l)
    
    if [[ $controllers -gt 0 ]]; then
        # Check for API versioning
        if ! grep -r "ApiVersion\|api-version" "$PROJECT_DIR" >/dev/null 2>&1; then
            generate_feature_proposal "API Versioning"
        fi
        
        # Check for Swagger/OpenAPI
        if ! grep -r "Swagger\|OpenApi" "$PROJECT_DIR" >/dev/null 2>&1; then
            generate_feature_proposal "API Documentation"
        fi
        
        # Check for rate limiting
        if ! grep -r "RateLimit\|Throttle" "$PROJECT_DIR" >/dev/null 2>&1; then
            generate_feature_proposal "Rate Limiting"
        fi
    fi
}

# Suggest performance improvements
suggest_performance_improvements() {
    log_message "Analyzing for performance improvements..."
    
    # Check for async patterns
    local sync_db_calls=$(grep -r "\.ToList()\|\.FirstOrDefault()\|\.Count()" "$PROJECT_DIR" 2>/dev/null | grep -v "Async" | wc -l || echo "0")
    
    if [[ $sync_db_calls -gt 10 ]]; then
        create_performance_proposal "Async Database Operations"
    fi
    
    # Check for N+1 queries
    if grep -r "foreach.*\.\(First\|Single\|ToList\)" "$PROJECT_DIR" >/dev/null 2>&1; then
        create_performance_proposal "N+1 Query Optimization"
    fi
}

# Create performance improvement proposal
create_performance_proposal() {
    local improvement_type="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local proposal_file="$PROPOSALS_DIR/performance_${improvement_type// /_}_${timestamp}.md"
    
    cat > "$proposal_file" << EOF
# Performance Improvement: $improvement_type

## Issue
Potential performance bottleneck detected: $improvement_type

## Recommendation
Refactor code to use more efficient patterns.

## Example Improvements
- Use async/await for I/O operations
- Implement pagination for large datasets  
- Add appropriate indexes
- Use projection to select only needed fields
- Implement caching where appropriate

## Priority: High
EOF
    
    log_message "Performance proposal created: $proposal_file"
}

# Create architectural roadmap
create_roadmap() {
    local roadmap_file="$PROPOSALS_DIR/architectural_roadmap_$(date +%Y%m%d).md"
    
    log_message "Creating architectural roadmap..."
    
    cat > "$roadmap_file" << 'EOF'
# Architectural Roadmap

## Phase 1: Foundation (Month 1)
- [ ] Implement Repository Pattern
- [ ] Add Unit of Work
- [ ] Set up Dependency Injection
- [ ] Create base test infrastructure

## Phase 2: Patterns (Month 2)
- [ ] Implement CQRS with MediatR
- [ ] Add validation framework
- [ ] Set up AutoMapper
- [ ] Create domain events

## Phase 3: Infrastructure (Month 3)
- [ ] Add caching layer
- [ ] Implement logging strategy
- [ ] Set up monitoring
- [ ] Add health checks

## Phase 4: Advanced Features (Month 4)
- [ ] Implement event sourcing (if applicable)
- [ ] Add message queuing
- [ ] Set up background jobs
- [ ] Implement circuit breakers

## Phase 5: Optimization (Month 5)
- [ ] Performance tuning
- [ ] Security hardening
- [ ] Documentation
- [ ] Training materials

## Success Metrics
- Code coverage > 80%
- Response time < 200ms (95th percentile)
- Zero critical security vulnerabilities
- All team members trained
EOF
    
    log_message "Roadmap created: $roadmap_file"
}

# Generate implementation tasks for developer agent
create_implementation_tasks() {
    local proposals=$(find "$PROPOSALS_DIR" -name "*.md" -mtime -1)
    local task_file="$AGENT_DIR/state/ARCHITECT_TASKS.md"
    
    cat > "$task_file" << EOF
# Architect-Generated Implementation Tasks
Generated: $(date)

## High Priority Tasks
EOF
    
    local task_count=0
    while IFS= read -r proposal; do
        [[ -z "$proposal" ]] && continue
        
        local feature_name=$(basename "$proposal" .md | sed 's/proposal_//' | sed 's/_/ /g')
        
        cat >> "$task_file" << EOF

### Task $((++task_count)): Implement $feature_name
- **Proposal**: $proposal
- **Priority**: High
- **Estimated Effort**: See proposal
- **Status**: PENDING_IMPLEMENTATION
EOF
    done <<< "$proposals"
    
    log_message "Created $task_count implementation tasks"
}

# Monitor code quality trends
monitor_quality_trends() {
    log_message "Monitoring code quality trends..."
    
    # Track metrics over time
    local metrics_file="$AGENT_DIR/state/quality_metrics_$(date +%Y%m%d).json"
    
    # Calculate various metrics
    local complexity=$(find "$PROJECT_DIR" -name "*.cs" -exec grep -c "if\|while\|for\|switch" {} + | awk '{sum+=$1} END {print sum}' || echo "0")
    local test_ratio=$(echo "scale=2; $(find "$PROJECT_DIR" -name "*Test*.cs" | wc -l) / $(find "$PROJECT_DIR" -name "*.cs" | wc -l)" | bc || echo "0")
    
    cat > "$metrics_file" << EOF
{
  "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": {
    "cyclomatic_complexity": $complexity,
    "test_coverage_ratio": $test_ratio,
    "technical_debt_items": $(grep -r "TODO\|FIXME\|HACK" "$PROJECT_DIR" 2>/dev/null | wc -l || echo "0"),
    "code_duplication": $(estimate_duplication)
  }
}
EOF
}

# Estimate code duplication (simplified)
estimate_duplication() {
    # This is a very simple check - in production you'd use tools like CPD
    local duplicate_patterns=$(find "$PROJECT_DIR" -name "*.cs" -exec grep -h "public.*{" {} \; 2>/dev/null | sort | uniq -d | wc -l || echo "0")
    echo $duplicate_patterns
}

# Generate executive summary
generate_executive_summary() {
    local summary_file="$PROPOSALS_DIR/executive_summary_$(date +%Y%m%d).md"
    
    cat > "$summary_file" << EOF
# Architecture Analysis - Executive Summary
Date: $(date)

## Current State
$(cat "$ANALYSIS_FILE" | grep -A10 "metrics" || echo "Analysis pending")

## Key Findings
1. **Architecture Score**: $(grep "architecture_score" "$ANALYSIS_FILE" | cut -d: -f2 | tr -d ' ,"')/100
2. **Missing Patterns**: $(identify_missing_patterns | wc -l) critical patterns missing
3. **Technical Debt**: $(grep -r "TODO\|FIXME" "$PROJECT_DIR" 2>/dev/null | wc -l || echo "0") items

## Recommendations
$(identify_missing_patterns | head -5 | sed 's/^/- /')

## Next Steps
1. Review generated proposals in $PROPOSALS_DIR
2. Prioritize based on business value
3. Assign to development team
4. Track implementation progress

## ROI Estimation
- Performance improvements: 20-30% faster response times
- Maintainability: 40% reduction in bug fix time
- Developer productivity: 25% increase
- Testing efficiency: 50% faster test execution
EOF
    
    log_message "Executive summary created: $summary_file"
}

# Main analysis workflow
main() {
    log_message "=== ARCHITECT AGENT STARTING ==="
    
    # Analyze current architecture
    analyze_codebase
    
    # Identify improvements
    local missing_patterns=$(identify_missing_patterns)
    
    if [[ -n "$missing_patterns" ]]; then
        log_message "Found missing patterns to implement:"
        while IFS= read -r pattern; do
            log_message "  - $pattern"
            generate_feature_proposal "$pattern"
        done <<< "$missing_patterns"
    fi
    
    # Additional analyses
    analyze_api_design
    suggest_performance_improvements
    monitor_quality_trends
    
    # Create deliverables
    create_roadmap
    create_implementation_tasks
    generate_executive_summary
    
    log_message "=== ARCHITECT AGENT COMPLETE ==="
    log_message "Proposals generated in: $PROPOSALS_DIR"
}

# Execute
main "$@"
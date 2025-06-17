#!/bin/bash
# User Story Agent - Creates and manages user stories with proper formatting and acceptance criteria
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORY_STATE="$SCRIPT_DIR/state/user_story"
mkdir -p "$STORY_STATE/stories" "$STORY_STATE/epics" "$STORY_STATE/templates"

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
MAGENTA='\033[0;35m'
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${MAGENTA}║        User Story Agent v1.0           ║${NC}"
    echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════╝${NC}"
}

# Create user story
create_user_story() {
    local story_type="${1:-feature}"
    local persona="${2:-user}"
    local need="${3:-perform an action}"
    local benefit="${4:-achieve a goal}"
    local story_id="US-$(date +%s)"
    local output_file="$STORY_STATE/stories/${story_id}.md"
    
    log_event "INFO" "USER_STORY" "Creating $story_type story: $story_id"
    
    cat > "$output_file" << EOF
# User Story: ${story_id}

## Story
**As a** $persona,
**I want to** $need,
**So that** $benefit.

## Story Details

### Type
$story_type

### Priority
P1 - High

### Size
Medium (5 story points)

### Business Value
High - Core functionality that directly impacts user experience

## Acceptance Criteria

### Functional Criteria
- [ ] Given: User is on the main page
      When: User performs the action
      Then: Expected result occurs

- [ ] Given: User has valid permissions
      When: User attempts the action
      Then: Action is completed successfully

- [ ] Given: User lacks permissions
      When: User attempts the action
      Then: Appropriate error message is displayed

### Non-Functional Criteria
- [ ] Response time < 2 seconds
- [ ] Works on all supported browsers
- [ ] Accessible via keyboard navigation
- [ ] Mobile responsive design
- [ ] Follows design system guidelines

## Technical Considerations

### Implementation Notes
- Consider using existing components
- Ensure proper error handling
- Add appropriate logging
- Include unit tests
- Update documentation

### Dependencies
- Authentication service must be available
- Database schema needs to support new fields
- API endpoints need to be defined

### Security Considerations
- Input validation required
- Authorization checks needed
- Audit logging for sensitive actions
- CSRF protection enabled

## Definition of Done

### Development
- [ ] Code complete and peer reviewed
- [ ] Unit tests written and passing (>80% coverage)
- [ ] Integration tests passing
- [ ] No critical SonarQube issues
- [ ] Documentation updated

### Testing
- [ ] QA testing completed
- [ ] Acceptance criteria verified
- [ ] Regression testing passed
- [ ] Performance benchmarks met
- [ ] Security scan passed

### Deployment
- [ ] Deployed to staging environment
- [ ] Smoke tests passing
- [ ] Feature flag configured (if applicable)
- [ ] Monitoring alerts configured
- [ ] Rollback plan documented

## User Experience

### Mockups
[Link to design mockups]

### User Flow
1. User navigates to feature
2. User interacts with UI
3. System processes request
4. User receives feedback
5. Action is completed

### Error Scenarios
1. Network failure - Show retry option
2. Validation error - Highlight fields with inline errors
3. Permission denied - Redirect to appropriate page
4. System error - Display friendly error message

## Test Cases

### Happy Path
1. **Test Case**: Successful action completion
   - **Given**: Valid user with permissions
   - **When**: User performs action with valid data
   - **Then**: Action completes successfully
   - **Expected**: Success message displayed

### Edge Cases
1. **Test Case**: Boundary values
   - **Given**: User enters maximum allowed values
   - **When**: Form is submitted
   - **Then**: System handles gracefully

2. **Test Case**: Concurrent access
   - **Given**: Multiple users accessing same resource
   - **When**: Simultaneous updates occur
   - **Then**: Proper conflict resolution

### Error Cases
1. **Test Case**: Invalid input
   - **Given**: User enters invalid data
   - **When**: Form is submitted
   - **Then**: Validation errors displayed

## Estimation Breakdown

### Development Tasks
- Frontend implementation (8h)
- Backend API development (6h)
- Database changes (2h)
- Integration work (4h)
- Unit tests (4h)
- Documentation (2h)
**Total Development**: 26h

### Testing Tasks
- Test case creation (2h)
- Manual testing (4h)
- Automation (4h)
- Bug fixes (4h)
**Total Testing**: 14h

**Total Estimate**: 40h (5 days)

## Related Stories
- Parent Epic: [EPIC-123]
- Depends on: [US-456]
- Blocks: [US-789]
- Related to: [US-012]

## Conversation History

### Questions & Answers
**Q**: What happens if the user loses connection mid-action?
**A**: System should save draft state and allow resume

**Q**: Should we support bulk operations?
**A**: Not in initial version, consider for v2

### Decisions Made
1. Use optimistic UI updates for better UX
2. Implement retry logic with exponential backoff
3. Add feature flag for gradual rollout

## Metrics & Monitoring

### Success Metrics
- Feature adoption rate > 60%
- Error rate < 1%
- User satisfaction > 4/5
- Performance SLA met 99.9%

### Monitoring Setup
- Custom dashboard for feature metrics
- Alerts for error rate spikes
- Performance tracking
- User behavior analytics

---
*Story created by User Story Agent*
*Created: $(date)*
*Last updated: $(date)*
EOF

    # Create JSON version for other agents
    cat > "$STORY_STATE/stories/${story_id}.json" << EOF
{
  "id": "$story_id",
  "type": "$story_type",
  "persona": "$persona",
  "need": "$need",
  "benefit": "$benefit",
  "priority": "P1",
  "points": 5,
  "status": "draft",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "acceptance_criteria": {
    "functional": 3,
    "non_functional": 5,
    "total": 8
  },
  "estimates": {
    "development_hours": 26,
    "testing_hours": 14,
    "total_hours": 40
  }
}
EOF
    
    echo -e "${GREEN}✓ User story created: $story_id${NC}"
    log_event "SUCCESS" "USER_STORY" "Story created: $story_id"
}

# Create epic
create_epic() {
    local epic_name="${1:-New Feature}"
    local business_value="${2:-Improve user experience}"
    local epic_id="EPIC-$(date +%s)"
    local output_file="$STORY_STATE/epics/${epic_id}.md"
    
    log_event "INFO" "USER_STORY" "Creating epic: $epic_id"
    
    cat > "$output_file" << EOF
# Epic: ${epic_id}

## Epic Title
$epic_name

## Epic Description
This epic encompasses all work required to deliver $epic_name, providing significant value by $business_value.

## Business Case

### Problem Statement
Current users face challenges with existing functionality, leading to decreased satisfaction and efficiency.

### Proposed Solution
Implement $epic_name to address user needs and improve overall experience.

### Expected Benefits
1. Increased user satisfaction by 25%
2. Reduced support tickets by 30%
3. Improved task completion rate by 40%
4. Enhanced system performance

### Success Criteria
- All child stories completed
- Feature adoption > 70%
- Performance benchmarks met
- Positive user feedback

## Scope

### In Scope
- Core functionality implementation
- User interface updates
- API development
- Documentation
- Testing and QA

### Out of Scope
- Advanced features (planned for v2)
- Third-party integrations
- Mobile app changes
- Legacy system migration

## User Stories

### Priority 0 (Must Have)
1. **[US-001]** User Authentication
   - Points: 8
   - Status: Not Started
   
2. **[US-002]** Basic Dashboard
   - Points: 13
   - Status: Not Started

3. **[US-003]** Core Workflow
   - Points: 21
   - Status: Not Started

### Priority 1 (Should Have)
4. **[US-004]** Advanced Filtering
   - Points: 8
   - Status: Not Started

5. **[US-005]** Export Functionality
   - Points: 5
   - Status: Not Started

### Priority 2 (Nice to Have)
6. **[US-006]** Customization Options
   - Points: 13
   - Status: Not Started

## Technical Architecture

### High-Level Design
\`\`\`
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Frontend  │────▶│     API     │────▶│   Backend   │
│   (React)   │◀────│  (GraphQL)  │◀────│  (Node.js)  │
└─────────────┘     └─────────────┘     └─────────────┘
                            │                    │
                            ▼                    ▼
                    ┌─────────────┐     ┌─────────────┐
                    │    Cache    │     │  Database   │
                    │   (Redis)   │     │ (PostgreSQL)│
                    └─────────────┘     └─────────────┘
\`\`\`

### Key Components
1. User Interface Layer
2. Business Logic Layer
3. Data Access Layer
4. Infrastructure Layer

### Technology Stack
- Frontend: React + TypeScript
- Backend: Node.js + Express
- Database: PostgreSQL
- Cache: Redis
- Queue: RabbitMQ

## Dependencies & Risks

### Dependencies
1. Design team approval
2. Infrastructure provisioning
3. Third-party service integration
4. Security review completion

### Risks
| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Scope creep | High | Medium | Strict change control |
| Technical complexity | High | Low | Proof of concept first |
| Resource availability | Medium | Medium | Cross-training team |
| Integration issues | Medium | Low | Early testing |

## Timeline & Milestones

### Phase 1: Foundation (Sprint 1-2)
- Technical design complete
- Infrastructure setup
- Basic authentication

### Phase 2: Core Features (Sprint 3-5)
- Main functionality
- API development
- Initial UI

### Phase 3: Enhancement (Sprint 6-7)
- Advanced features
- Performance optimization
- Polish

### Phase 4: Launch (Sprint 8)
- Final testing
- Documentation
- Deployment

## Metrics & KPIs

### Development Metrics
- Velocity trend
- Defect density
- Code coverage
- Technical debt

### Business Metrics
- Feature adoption rate
- User satisfaction score
- Support ticket reduction
- Performance improvement

### Quality Metrics
- Defect escape rate
- Test automation coverage
- Code review turnaround
- Documentation completeness

## Stakeholders

### Core Team
- Product Owner: Makes priority decisions
- Tech Lead: Technical decisions
- UX Designer: User experience
- QA Lead: Quality assurance

### Extended Team
- Business Analyst: Requirements
- Solutions Architect: Architecture
- DevOps: Infrastructure
- Support Team: User feedback

## Communication Plan

### Regular Updates
- Weekly status to stakeholders
- Daily standups with team
- Sprint reviews every 2 weeks
- Monthly steering committee

### Escalation Path
1. Team Lead
2. Product Owner
3. Program Manager
4. Executive Sponsor

---
*Epic created by User Story Agent*
*Created: $(date)*
EOF

    # Create epic summary JSON
    cat > "$STORY_STATE/epics/${epic_id}_summary.json" << EOF
{
  "id": "$epic_id",
  "name": "$epic_name",
  "business_value": "$business_value",
  "total_points": 68,
  "stories": {
    "p0": 3,
    "p1": 2,
    "p2": 1,
    "total": 6
  },
  "timeline": {
    "sprints": 8,
    "weeks": 16
  },
  "status": "not_started",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo -e "${GREEN}✓ Epic created: $epic_id${NC}"
    log_event "SUCCESS" "USER_STORY" "Epic created: $epic_id"
}

# Generate story from requirement
generate_from_requirement() {
    local requirement="${1:-User needs to log in}"
    local output_file="$STORY_STATE/stories/generated_$(date +%s).md"
    
    log_event "INFO" "USER_STORY" "Generating story from requirement: $requirement"
    
    # Parse requirement to extract key elements
    local action="perform the required action"
    local benefit="accomplish their goal"
    
    if [[ "$requirement" =~ log[[:space:]]?in ]]; then
        action="log in to the system"
        benefit="access personalized features and data"
    elif [[ "$requirement" =~ search ]]; then
        action="search for information"
        benefit="quickly find what I need"
    elif [[ "$requirement" =~ upload ]]; then
        action="upload files"
        benefit="share documents with the team"
    fi
    
    create_user_story "feature" "user" "$action" "$benefit"
}

# Create story template
create_story_template() {
    local template_name="${1:-default}"
    local output_file="$STORY_STATE/templates/${template_name}_template.md"
    
    log_event "INFO" "USER_STORY" "Creating story template: $template_name"
    
    cat > "$output_file" << 'EOF'
# User Story Template: ${TEMPLATE_NAME}

## Story Format
**As a** [type of user],
**I want to** [perform some action],
**So that** [achieve some benefit].

## Required Sections

### 1. Story Details
- Type: [feature/bug/technical/spike]
- Priority: [P0/P1/P2/P3]
- Size: [XS/S/M/L/XL]
- Business Value: [Critical/High/Medium/Low]

### 2. Acceptance Criteria
Use Given-When-Then format:
- Given [context]
  When [action]
  Then [outcome]

### 3. Technical Considerations
- Implementation approach
- Dependencies
- Security concerns
- Performance impact

### 4. Definition of Done
- [ ] Code complete
- [ ] Tests written
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] Deployed to staging

### 5. Estimation
- Development: X hours
- Testing: Y hours
- Total: Z hours

## Best Practices

### Good Story Characteristics (INVEST)
- **I**ndependent: Can be developed separately
- **N**egotiable: Details can be discussed
- **V**aluable: Provides business value
- **E**stimable: Can be sized
- **S**mall: Fits in one sprint
- **T**estable: Clear acceptance criteria

### Common Pitfalls to Avoid
1. Technical tasks disguised as stories
2. Stories too large (>13 points)
3. Vague acceptance criteria
4. Missing non-functional requirements
5. No clear business value

### Writing Tips
1. Focus on user needs, not implementation
2. Include context and motivation
3. Be specific but not prescriptive
4. Consider edge cases
5. Think about the full user journey

## Examples

### Good Example
**As a** registered user,
**I want to** reset my password via email,
**So that** I can regain access to my account if I forget my password.

### Poor Example
**As a** developer,
**I want to** refactor the authentication module,
**So that** the code is cleaner.

### Improved Version
**As a** system administrator,
**I want to** improve authentication system maintainability,
**So that** we can add new authentication methods quickly and safely.

---
*Template: ${TEMPLATE_NAME}*
*Use this template as a starting point for creating consistent user stories*
EOF
    
    echo -e "${GREEN}✓ Story template created: $template_name${NC}"
    log_event "SUCCESS" "USER_STORY" "Template created: $template_name"
}

# Split story
split_story() {
    local story_id="${1:-US-001}"
    local parts="${2:-3}"
    local output_dir="$STORY_STATE/stories/split_${story_id}"
    
    mkdir -p "$output_dir"
    log_event "INFO" "USER_STORY" "Splitting story $story_id into $parts parts"
    
    for i in $(seq 1 "$parts"); do
        cat > "$output_dir/part_${i}.md" << EOF
# User Story: ${story_id}-Part${i}

## Parent Story
Original: ${story_id}
Part ${i} of ${parts}

## Story
**As a** user,
**I want to** complete part ${i} of the feature,
**So that** I can incrementally deliver value.

## Scope for This Part
- Specific functionality for part ${i}
- Limited to essential features
- Can be deployed independently
- Provides partial value

## Acceptance Criteria
- [ ] Part ${i} functionality working
- [ ] No regression on existing features
- [ ] Can be tested independently
- [ ] Documentation updated for part ${i}

## Dependencies
- Previous parts: $([ $i -gt 1 ] && echo "Part 1-$((i-1))" || echo "None")
- External: Defined in parent story

## Estimation
- Original total: 13 points
- This part: $((13 / parts)) points
- Remaining: $((13 - (13 / parts * i))) points

---
*Split from story ${story_id}*
*Part ${i} of ${parts}*
EOF
    done
    
    echo -e "${GREEN}✓ Story split into $parts parts${NC}"
    log_event "SUCCESS" "USER_STORY" "Story $story_id split into $parts parts"
}

# Analyze story quality
analyze_story_quality() {
    local story_file="${1:-$STORY_STATE/stories/US-latest.md}"
    local output_file="$STORY_STATE/stories/quality_report.md"
    
    log_event "INFO" "USER_STORY" "Analyzing story quality"
    
    cat > "$output_file" << 'EOF'
# User Story Quality Analysis

## INVEST Criteria Assessment

### Independent ✓
- Story can be developed without waiting for other stories
- No circular dependencies identified
- Clear boundaries defined

### Negotiable ⚠️
- Implementation details somewhat prescribed
- Consider removing technical specifications
- Focus more on outcomes vs. solutions

### Valuable ✓
- Clear business value stated
- User benefit well articulated
- Aligns with product goals

### Estimable ✓
- Sufficient detail for estimation
- Complexity is understood
- Technical approach is clear

### Small ⚠️
- 5 points is borderline for one sprint
- Consider splitting if risks emerge
- Monitor progress closely

### Testable ✓
- Clear acceptance criteria
- Specific test cases defined
- Success metrics identified

## Quality Score: 8/10

## Strengths
1. Well-defined acceptance criteria
2. Clear user persona and need
3. Good technical considerations
4. Comprehensive test cases

## Areas for Improvement
1. **Too Technical**: Remove implementation details from story
2. **Size Concern**: Consider breaking into smaller pieces
3. **Missing Context**: Add more business context
4. **Metrics**: Define specific success metrics

## Recommendations

### Immediate Actions
1. Move technical details to separate tech spec
2. Add specific success metrics
3. Include more user journey context
4. Review with stakeholders

### Before Development
1. Validate with actual users
2. Confirm technical feasibility
3. Review dependencies
4. Update estimates if needed

## Checklist Compliance

### Required Elements ✓
- [x] User story format
- [x] Acceptance criteria
- [x] Definition of done
- [x] Estimation
- [x] Priority

### Best Practices
- [x] User-focused
- [x] Business value clear
- [ ] Implementation agnostic
- [x] Testable criteria
- [ ] Metrics defined

## Similar Stories Analysis
Compared to previous stories:
- Complexity: Average
- Quality: Above average
- Clarity: Good
- Completeness: Very good

---
*Quality analysis by User Story Agent*
*Generated: $(date)*
EOF
    
    echo -e "${GREEN}✓ Story quality analysis complete${NC}"
    log_event "SUCCESS" "USER_STORY" "Quality analysis complete"
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        create)
            shift
            create_user_story "$@"
            ;;
        epic)
            create_epic "${2:-New Feature}" "${3:-Improve user experience}"
            ;;
        generate)
            generate_from_requirement "${2:-User needs to perform an action}"
            ;;
        template)
            create_story_template "${2:-default}"
            ;;
        split)
            split_story "${2:-US-001}" "${3:-3}"
            ;;
        analyze)
            analyze_story_quality "${2:-}"
            ;;
        init)
            echo -e "${CYAN}Initializing user story management...${NC}"
            create_story_template "default"
            create_story_template "bug"
            create_story_template "technical"
            create_user_story "feature" "user" "manage their profile" "keep their information up to date"
            create_epic "User Management System" "Provide comprehensive user management"
            echo -e "${GREEN}✓ User story management initialized!${NC}"
            echo -e "${YELLOW}Next steps:${NC}"
            echo "1. Review templates in: $STORY_STATE/templates/"
            echo "2. Create stories using: $0 create"
            echo "3. Analyze story quality: $0 analyze"
            ;;
        *)
            echo "Usage: $0 {create|epic|generate|template|split|analyze|init} [options]"
            echo ""
            echo "Commands:"
            echo "  create [type] [persona] [need] [benefit] - Create user story"
            echo "  epic [name] [value]                      - Create epic"
            echo "  generate [requirement]                   - Generate from requirement"
            echo "  template [name]                          - Create story template"
            echo "  split [story-id] [parts]                - Split large story"
            echo "  analyze [story-file]                    - Analyze story quality"
            echo "  init                                    - Initialize templates"
            exit 1
            ;;
    esac
}

main "$@"
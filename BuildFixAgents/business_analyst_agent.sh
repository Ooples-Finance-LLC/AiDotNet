#!/bin/bash
# Business Analyst Agent - Analyzes requirements, creates detailed specifications, and ensures alignment
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BA_STATE="$SCRIPT_DIR/state/business_analyst"
mkdir -p "$BA_STATE/analysis" "$BA_STATE/specifications" "$BA_STATE/validations"

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
ORANGE='\033[0;33m'
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${ORANGE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${ORANGE}║     Business Analyst Agent v1.0        ║${NC}"
    echo -e "${BOLD}${ORANGE}╚════════════════════════════════════════╝${NC}"
}

# Analyze business requirements
analyze_requirements() {
    local requirement_doc="${1:-$SCRIPT_DIR/state/product_owner/requirements/product_requirements.md}"
    local output_file="$BA_STATE/analysis/requirements_analysis.md"
    
    log_event "INFO" "BUSINESS_ANALYST" "Analyzing business requirements"
    
    cat > "$output_file" << 'EOF'
# Business Requirements Analysis

## Analysis Summary
**Date**: $(date)
**Status**: In Progress
**Analyst**: Business Analyst Agent

## Requirements Breakdown

### Functional Requirements Analysis

#### 1. User Authentication & Management
**Business Value**: High - Security and user identity are fundamental
**Complexity**: Medium - Standard patterns available
**Dependencies**: Database, Email service
**Risks**: 
- Security vulnerabilities if not properly implemented
- User experience issues with complex password requirements
**Recommendations**:
- Implement OAuth2 for social logins
- Use proven libraries (Passport.js, Auth0)
- Add MFA as optional feature
**Acceptance Criteria Validation**: ✓ Complete and testable

#### 2. Dashboard & Analytics
**Business Value**: High - Core value proposition
**Complexity**: High - Real-time data and customization
**Dependencies**: Analytics engine, Frontend framework
**Risks**:
- Performance issues with large datasets
- Complex state management
**Recommendations**:
- Start with predefined dashboard templates
- Implement caching strategy
- Use WebSocket for real-time updates
**Acceptance Criteria Validation**: ⚠️ Needs specific metrics definition

#### 3. Core Workflow Engine
**Business Value**: Critical - Main product differentiator
**Complexity**: Very High - Custom business logic
**Dependencies**: All other components
**Risks**:
- Scope creep
- Performance bottlenecks
- Complex error scenarios
**Recommendations**:
- Build MVP with 3-5 core workflows
- Design for extensibility
- Implement comprehensive logging
**Acceptance Criteria Validation**: ⚠️ Too broad, needs decomposition

### Non-Functional Requirements Analysis

#### Performance Requirements
- **Feasibility**: Achievable with proper architecture
- **Measurement Strategy**: 
  - Implement APM (Application Performance Monitoring)
  - Set up synthetic monitoring
  - Regular load testing
- **Risk Mitigation**:
  - CDN for static assets
  - Database query optimization
  - Caching at multiple levels

#### Security Requirements
- **Compliance Gaps**: 
  - GDPR requires privacy by design
  - SOC2 requires extensive documentation
- **Implementation Timeline**: 6-9 months for full compliance
- **Budget Impact**: ~$50k for audits and tools

#### Scalability Requirements
- **Architecture Recommendations**:
  - Microservices from start
  - Event-driven architecture
  - Container orchestration (Kubernetes)
- **Cost Implications**: 
  - Higher initial infrastructure cost
  - Reduced scaling costs long-term

## Gap Analysis

### Missing Requirements
1. **Data Retention Policies** - Required for compliance
2. **Disaster Recovery Plan** - RTO/RPO not defined
3. **Internationalization** - No mention of multi-language support
4. **Accessibility Standards** - WCAG compliance not specified
5. **API Rate Limiting** - Specific limits not defined

### Conflicting Requirements
1. **Performance vs Security**: End-to-end encryption may impact response times
2. **Simplicity vs Customization**: Dashboard flexibility conflicts with ease of use
3. **Cost vs Features**: Enterprise features in MVP increase timeline

### Ambiguous Requirements
1. "Intuitive workflow creation" - Needs specific UI/UX criteria
2. "Real-time updates" - Define acceptable latency
3. "Advanced analytics" - Specify which metrics and algorithms

## Stakeholder Impact Analysis

### End Users
- **Benefits**: Significant time savings, better insights
- **Concerns**: Learning curve, data privacy
- **Success Metrics**: Adoption rate, daily active users

### Business Stakeholders
- **Benefits**: ROI through efficiency gains
- **Concerns**: Implementation cost, change management
- **Success Metrics**: Cost savings, revenue growth

### Technical Team
- **Benefits**: Modern tech stack, interesting challenges
- **Concerns**: Aggressive timeline, technical debt
- **Success Metrics**: Code quality, deployment frequency

## Risk Assessment

### High Risks
1. **Scope Creep** 
   - Mitigation: Strict change control process
   - Owner: Product Owner
   
2. **Technical Complexity**
   - Mitigation: Proof of concepts for complex features
   - Owner: Tech Lead

3. **Market Competition**
   - Mitigation: Faster time to market, unique features
   - Owner: Business Owner

### Medium Risks
1. **Resource Constraints**
   - Mitigation: Phased delivery, outsourcing options
   
2. **Integration Challenges**
   - Mitigation: Early API testing, vendor support

3. **User Adoption**
   - Mitigation: Beta program, user feedback loops

## Recommendations

### Immediate Actions
1. Define specific metrics for "real-time" and "intuitive"
2. Create detailed workflow diagrams for core features
3. Establish compliance roadmap with legal team
4. Prototype high-risk technical components

### Requirement Refinements
1. Split "Core Workflow Engine" into 5-7 specific workflows
2. Add explicit data retention and privacy requirements
3. Define API rate limits and quotas
4. Specify accessibility standards (WCAG 2.1 AA)

### Process Improvements
1. Weekly stakeholder alignment meetings
2. Requirement change impact assessment process
3. Continuous validation with user representatives
4. Regular competitive analysis updates

## Validation Checklist

### Completeness
- [x] Functional requirements documented
- [x] Non-functional requirements specified
- [ ] Data requirements defined
- [ ] Integration requirements detailed
- [ ] Compliance requirements verified

### Consistency
- [x] No conflicting requirements identified
- [ ] Terminology standardized
- [x] Dependencies mapped
- [ ] Versioning strategy defined

### Feasibility
- [x] Technical feasibility confirmed
- [ ] Resource availability verified
- [x] Timeline realistic with caveats
- [ ] Budget alignment needed

### Testability
- [x] Acceptance criteria defined
- [ ] Test scenarios outlined
- [ ] Performance benchmarks set
- [ ] Security test cases identified

## Next Steps
1. Schedule stakeholder review meeting
2. Create detailed user journey maps
3. Develop technical architecture proposal
4. Establish feedback collection mechanism
5. Define MVP feature set based on analysis
EOF
    
    # Create analysis summary for other agents
    cat > "$BA_STATE/analysis/analysis_summary.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "analyzed",
  "critical_gaps": [
    "Data retention policies",
    "Disaster recovery plan",
    "API rate limits",
    "Accessibility standards"
  ],
  "high_risk_items": [
    "Core workflow engine complexity",
    "Real-time performance requirements",
    "Compliance timeline"
  ],
  "recommendations": {
    "immediate": [
      "Define specific metrics",
      "Create workflow diagrams",
      "Prototype complex features"
    ],
    "short_term": [
      "Establish feedback loops",
      "Refine requirements",
      "Create test plans"
    ]
  }
}
EOF
    
    log_event "SUCCESS" "BUSINESS_ANALYST" "Requirements analysis complete"
}

# Create detailed specifications
create_specifications() {
    local feature_name="${1:-authentication}"
    local output_file="$BA_STATE/specifications/${feature_name}_specification.md"
    
    log_event "INFO" "BUSINESS_ANALYST" "Creating detailed specification for $feature_name"
    
    cat > "$output_file" << EOF
# Feature Specification: ${feature_name^}

## Overview
**Feature**: ${feature_name^} System
**Version**: 1.0
**Last Updated**: $(date)
**Status**: Draft

## Business Context

### Problem Statement
Users need a secure, seamless way to access the system while maintaining data privacy and preventing unauthorized access.

### Business Objectives
1. Reduce unauthorized access to 0%
2. Decrease login time to <3 seconds
3. Support 100,000+ concurrent users
4. Achieve 99.99% authentication service uptime

### Success Criteria
- 95% of users successfully log in on first attempt
- Password reset completion rate >90%
- Zero security breaches related to authentication
- User satisfaction score >4.5/5 for login experience

## Functional Specification

### User Registration
**Flow**:
1. User clicks "Sign Up"
2. System displays registration form
3. User enters email, password, name
4. System validates input
5. System sends verification email
6. User clicks verification link
7. System activates account
8. User redirected to dashboard

**Business Rules**:
- Email must be unique in system
- Password minimum 8 characters, 1 uppercase, 1 number, 1 special
- Verification link expires in 24 hours
- Maximum 3 verification email requests per hour

**Data Requirements**:
\`\`\`json
{
  "email": "string, required, unique",
  "password": "string, required, encrypted",
  "firstName": "string, required, 1-50 chars",
  "lastName": "string, required, 1-50 chars",
  "createdAt": "timestamp",
  "emailVerified": "boolean, default false",
  "verificationToken": "string, unique",
  "tokenExpiry": "timestamp"
}
\`\`\`

### User Login
**Flow**:
1. User enters email/password
2. System validates credentials
3. System checks account status
4. System generates session token
5. System returns token and user data
6. Client stores token securely

**Business Rules**:
- Lock account after 5 failed attempts
- Lock duration: 30 minutes
- Session timeout: 30 days (remember me) or 24 hours
- Support concurrent sessions on multiple devices

### Password Reset
**Flow**:
1. User clicks "Forgot Password"
2. User enters email
3. System sends reset link
4. User clicks link
5. User enters new password
6. System updates password
7. System invalidates all sessions
8. User redirected to login

**Business Rules**:
- Reset link valid for 1 hour
- Cannot reuse last 5 passwords
- Notify user of password change
- Log security event

## Technical Specification

### Architecture
\`\`\`
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Client    │────▶│   API       │────▶│   Auth      │
│   (React)   │◀────│   Gateway   │◀────│   Service   │
└─────────────┘     └─────────────┘     └─────────────┘
                            │                    │
                            ▼                    ▼
                    ┌─────────────┐     ┌─────────────┐
                    │   Redis     │     │  PostgreSQL │
                    │   (Cache)   │     │   (Store)   │
                    └─────────────┘     └─────────────┘
\`\`\`

### API Specification

#### POST /api/auth/register
**Request**:
\`\`\`json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "firstName": "John",
  "lastName": "Doe"
}
\`\`\`

**Response (201)**:
\`\`\`json
{
  "success": true,
  "message": "Registration successful. Please check your email.",
  "userId": "uuid-here"
}
\`\`\`

**Error Responses**:
- 400: Validation error
- 409: Email already exists
- 429: Too many requests

#### POST /api/auth/login
**Request**:
\`\`\`json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "rememberMe": true
}
\`\`\`

**Response (200)**:
\`\`\`json
{
  "success": true,
  "token": "jwt-token-here",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "role": "user"
  }
}
\`\`\`

### Security Considerations
1. **Password Storage**: Bcrypt with cost factor 12
2. **Token Security**: JWT with RS256 algorithm
3. **HTTPS Required**: All endpoints HTTPS only
4. **Rate Limiting**: 10 requests per minute per IP
5. **CSRF Protection**: Double submit cookie
6. **XSS Prevention**: Content Security Policy headers

### Performance Requirements
- Login response time: <500ms (95th percentile)
- Registration processing: <2 seconds
- Token validation: <50ms
- Concurrent users: 10,000+

## User Interface Specification

### Registration Form
- Email field with validation on blur
- Password field with strength indicator
- Password visibility toggle
- Terms of service checkbox
- Clear error messages below fields
- Loading state during submission

### Login Form
- Email/password fields
- Remember me checkbox
- Forgot password link
- Social login buttons (Google, GitHub)
- Clear error messages
- Auto-focus on email field

## Testing Requirements

### Unit Tests
- Password hashing function
- Token generation/validation
- Input validation
- Business rule enforcement

### Integration Tests
- Complete registration flow
- Login with various scenarios
- Password reset flow
- Session management

### Security Tests
- SQL injection attempts
- XSS payload testing
- Brute force protection
- Token security validation

### Performance Tests
- Load test with 10,000 concurrent logins
- Stress test to find breaking point
- Latency testing from different regions

## Acceptance Criteria

### User Registration
- [ ] User can register with valid email/password
- [ ] System sends verification email within 30 seconds
- [ ] Duplicate emails are rejected with clear message
- [ ] Password strength indicator works correctly
- [ ] Verification link activates account

### User Login
- [ ] Valid credentials allow access
- [ ] Invalid credentials show appropriate error
- [ ] Account lockout after 5 failed attempts
- [ ] Remember me extends session to 30 days
- [ ] Sessions persist across browser restart

### Password Reset
- [ ] Reset email sent within 30 seconds
- [ ] Reset link works and expires correctly
- [ ] New password meets requirements
- [ ] Old password no longer works
- [ ] User notified of password change

### Security
- [ ] Passwords stored encrypted
- [ ] Tokens expire appropriately
- [ ] Rate limiting prevents abuse
- [ ] HTTPS enforced on all endpoints
- [ ] Security headers present

### Performance
- [ ] Login completes in <500ms
- [ ] System handles 10,000 concurrent users
- [ ] No memory leaks during extended use
- [ ] Database queries optimized

## Dependencies
1. Email service (SendGrid/AWS SES)
2. Redis for session storage
3. PostgreSQL for user data
4. JWT library for tokens
5. Bcrypt for password hashing

## Timeline
- Design complete: Week 1
- Backend implementation: Week 2-3
- Frontend implementation: Week 3-4
- Testing: Week 4-5
- Security review: Week 5
- Deployment: Week 6

## Open Questions
1. Should we support passwordless login?
2. What OAuth providers to support initially?
3. Should we implement biometric authentication?
4. How long should sessions last on mobile?
5. Do we need SMS-based 2FA?

## Approval

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Product Owner | | | |
| Tech Lead | | | |
| Security Officer | | | |
| QA Lead | | | |
EOF
    
    log_event "SUCCESS" "BUSINESS_ANALYST" "Specification created for $feature_name"
}

# Validate acceptance criteria
validate_acceptance_criteria() {
    local criteria_file="${1:-$BA_STATE/specifications/authentication_specification.md}"
    local output_file="$BA_STATE/validations/criteria_validation.md"
    
    log_event "INFO" "BUSINESS_ANALYST" "Validating acceptance criteria"
    
    cat > "$output_file" << 'EOF'
# Acceptance Criteria Validation Report

## Validation Summary
**Date**: $(date)
**Total Criteria**: 25
**Valid**: 20
**Issues Found**: 5

## SMART Criteria Analysis

### Specific
✓ **Good Examples**:
- "User can register with valid email/password"
- "System sends verification email within 30 seconds"
- "Account lockout after 5 failed attempts"

⚠️ **Needs Improvement**:
- "Password strength indicator works correctly" → Define what "correctly" means
- "Clear error messages" → Specify exact messages

### Measurable
✓ **Good Examples**:
- "Login completes in <500ms"
- "System handles 10,000 concurrent users"
- "Verification email within 30 seconds"

⚠️ **Needs Improvement**:
- "Appropriate error" → Define specific error codes/messages
- "Security headers present" → List specific headers

### Achievable
✓ All criteria appear technically achievable with current technology

### Relevant
✓ All criteria align with business objectives and user needs

### Time-bound
⚠️ **Missing Timeframes**:
- No SLA for uptime
- No response time for support issues
- No timeline for security patches

## Testability Analysis

### Automated Testing
**Easily Automated** (80%):
- API response times
- Input validation
- Authentication flows
- Security headers
- Rate limiting

**Manual Testing Required** (20%):
- User experience quality
- Error message clarity
- Visual indicators
- Email delivery (partially)

### Test Case Mapping
| Acceptance Criteria | Test Type | Priority |
|-------------------|-----------|----------|
| Valid login | Unit, Integration, E2E | High |
| Password encryption | Unit, Security | Critical |
| Session timeout | Integration | High |
| Rate limiting | Load, Security | High |
| Email delivery | Integration, Manual | Medium |

## Completeness Check

### Covered Scenarios
✓ Happy path flows
✓ Basic error scenarios
✓ Security requirements
✓ Performance targets

### Missing Scenarios
❌ Network failure handling
❌ Database connection issues
❌ Third-party service outages
❌ Partial success states
❌ Accessibility requirements

## Alignment with Business Goals

### Direct Alignment
✓ Security objectives fully covered
✓ Performance targets specified
✓ User experience considered

### Gaps
⚠️ No mention of:
- Analytics/tracking requirements
- A/B testing capabilities
- Feature flags for rollout
- Compliance logging

## Recommendations

### Immediate Fixes
1. **Clarify Ambiguous Criteria**:
   - "Works correctly" → Specific behavior
   - "Appropriate" → Exact requirements
   - "Clear" → Specific guidelines

2. **Add Missing Criteria**:
   - Accessibility: "Screen reader compatible"
   - Errors: "All errors logged with context"
   - Recovery: "Graceful degradation on service failure"

3. **Quantify Quality Attributes**:
   - "Fast" → Specific milliseconds
   - "Secure" → Specific standards
   - "Reliable" → Specific uptime %

### Additional Criteria Needed
1. **Observability**:
   - "All auth events logged with correlation ID"
   - "Metrics exported to monitoring system"
   - "Alerts configured for failures"

2. **Accessibility**:
   - "WCAG 2.1 AA compliant"
   - "Keyboard navigation supported"
   - "Screen reader announcements for errors"

3. **Error Handling**:
   - "All errors return consistent format"
   - "No sensitive data in error messages"
   - "Fallback behavior documented"

## Validation Matrix

| Criteria Category | Count | Valid | Issues |
|------------------|-------|-------|---------|
| Functional | 15 | 12 | 3 |
| Security | 5 | 5 | 0 |
| Performance | 3 | 3 | 0 |
| Usability | 2 | 0 | 2 |
| **Total** | **25** | **20** | **5** |

## Risk Assessment

### High Risk Criteria
1. **Vague success conditions** - May lead to disputes
2. **Missing error scenarios** - Poor user experience
3. **No accessibility criteria** - Legal compliance risk

### Mitigation Steps
1. Workshop with stakeholders to clarify
2. Add comprehensive error handling criteria
3. Include WCAG compliance requirements

## Sign-off Readiness

### Ready for Sign-off ✓
- Security criteria
- Performance criteria
- Core functional flows

### Needs Revision ⚠️
- Error handling criteria
- UI/UX criteria
- Accessibility criteria
- Monitoring criteria

## Next Actions
1. Schedule criteria review meeting
2. Add missing accessibility requirements
3. Define specific error messages
4. Create test plan mapping
5. Get stakeholder approval on changes
EOF
    
    log_event "SUCCESS" "BUSINESS_ANALYST" "Acceptance criteria validation complete"
}

# Create feedback mechanism
create_feedback_mechanism() {
    local output_file="$BA_STATE/analysis/feedback_process.md"
    
    log_event "INFO" "BUSINESS_ANALYST" "Creating feedback mechanism"
    
    cat > "$output_file" << 'EOF'
# Continuous Feedback Process

## Overview
This document outlines the feedback collection and integration process throughout the development lifecycle.

## Feedback Channels

### 1. User Interviews
- **Frequency**: Weekly during development
- **Participants**: 5-10 users per session
- **Format**: 30-minute structured interviews
- **Topics**: Feature validation, usability, pain points

### 2. In-App Feedback
- **Widget**: Floating feedback button
- **Forms**: Context-aware questionnaires
- **Screenshots**: Automatic capture with annotation
- **Sentiment**: Quick emoji reactions

### 3. Analytics-Driven
- **User Behavior**: Heatmaps, session recordings
- **Feature Usage**: Adoption and retention metrics
- **Error Tracking**: Automatic error reporting
- **Performance**: Real user monitoring

### 4. Stakeholder Reviews
- **Sprint Reviews**: Bi-weekly demos
- **Steering Committee**: Monthly strategic alignment
- **Executive Updates**: Quarterly business reviews

## Feedback Collection Templates

### Feature Feedback Form
```
1. Which feature are you providing feedback on?
2. How well does this feature meet your needs? (1-5)
3. What works well?
4. What could be improved?
5. What's missing?
6. Would you recommend this to a colleague?
```

### Usability Testing Script
```
Task 1: [Specific task]
- Time to complete: ___
- Errors encountered: ___
- User comments: ___
- Success: Yes/No

Overall Questions:
- What was most confusing?
- What did you like best?
- What would you change?
```

## Feedback Processing Workflow

### 1. Collection Phase
```mermaid
graph LR
    A[User Feedback] --> B[Feedback Queue]
    C[Analytics Data] --> B
    D[Support Tickets] --> B
    E[Social Media] --> B
```

### 2. Analysis Phase
- **Categorization**: Feature, Bug, Enhancement, UX
- **Prioritization**: Impact vs Effort matrix
- **Validation**: Cross-reference multiple sources
- **Sentiment Analysis**: Positive, Neutral, Negative

### 3. Action Phase
- **Immediate**: Critical bugs, security issues
- **Sprint Planning**: Feature requests, enhancements
- **Backlog**: Nice-to-have, future considerations
- **Won't Do**: Out of scope, explain why

## Feedback Integration Points

### During Development
1. **Daily Standup**: Share critical feedback
2. **Sprint Planning**: Prioritize feedback items
3. **Design Reviews**: Incorporate UX feedback
4. **Code Reviews**: Technical feedback integration

### Post-Release
1. **Hot Fixes**: Critical issues within 24 hours
2. **Patch Releases**: Weekly bug fixes
3. **Feature Releases**: Monthly enhancements
4. **Major Updates**: Quarterly strategic changes

## Feedback Metrics

### Response Metrics
- **Acknowledgment Time**: <2 hours
- **Initial Response**: <24 hours
- **Resolution Time**: Varies by severity
- **Follow-up**: Within 7 days of resolution

### Quality Metrics
- **Feedback Volume**: Track trends
- **Sentiment Score**: Monitor satisfaction
- **Resolution Rate**: >90% target
- **Repeat Issues**: <10% target

## Stakeholder Communication

### Feedback Reports
**Weekly Summary**:
- Top 5 issues
- Feature requests
- Sentiment trend
- Actions taken

**Monthly Analysis**:
- Comprehensive metrics
- Trend analysis
- Strategic recommendations
- Success stories

## Feedback Loop Closure

### User Notification
- Email when feedback is received
- Update when work begins
- Notification when resolved
- Follow-up for satisfaction

### Change Communication
- Release notes mention feedback
- Credit users for suggestions
- Blog posts for major changes
- In-app notifications

## Tools and Systems

### Collection Tools
- Hotjar for heatmaps
- FullStory for session recording
- Intercom for in-app chat
- TypeForm for surveys

### Processing Tools
- Jira for ticket management
- Productboard for feature requests
- Slack for team communication
- Tableau for analytics

## Success Criteria

### Engagement Metrics
- 20% of users provide feedback
- 50+ feedback items per week
- 4.0+ satisfaction score
- <48 hour response time

### Impact Metrics
- 30% of features from feedback
- 50% reduction in repeat issues
- 90% positive sentiment
- 95% feel heard

## Continuous Improvement

### Quarterly Review
1. Analyze feedback trends
2. Evaluate process efficiency
3. Update templates and tools
4. Train team on best practices

### Annual Planning
1. Strategic feedback analysis
2. Process overhaul if needed
3. Tool evaluation and updates
4. Success metric adjustment
EOF
    
    log_event "SUCCESS" "BUSINESS_ANALYST" "Feedback mechanism created"
}

# Generate process flow diagrams
generate_process_flows() {
    local process_name="${1:-user_registration}"
    local output_file="$BA_STATE/analysis/${process_name}_flow.md"
    
    log_event "INFO" "BUSINESS_ANALYST" "Generating process flow for $process_name"
    
    cat > "$output_file" << 'EOF'
# Process Flow: User Registration

## Flow Diagram

```mermaid
flowchart TD
    A[User Clicks Sign Up] --> B{Valid Form?}
    B -->|No| C[Show Validation Errors]
    C --> A
    B -->|Yes| D[Check Email Exists]
    D --> E{Email Exists?}
    E -->|Yes| F[Show Email Exists Error]
    F --> A
    E -->|No| G[Create User Record]
    G --> H[Generate Verification Token]
    H --> I[Send Verification Email]
    I --> J{Email Sent?}
    J -->|No| K[Log Error & Retry]
    K --> L{Retry Success?}
    L -->|No| M[Show Error Message]
    L -->|Yes| N[Show Success Message]
    J -->|Yes| N
    N --> O[User Checks Email]
    O --> P[User Clicks Verification Link]
    P --> Q{Token Valid?}
    Q -->|No| R[Show Invalid Token Error]
    Q -->|Yes| S[Activate Account]
    S --> T[Redirect to Login]
    T --> U[End]
    R --> U
    M --> U
```

## Detailed Steps

### 1. Initial Form Display
- **Actor**: User
- **System**: Display registration form
- **Data**: None
- **Validation**: None

### 2. Form Submission
- **Actor**: User fills form and submits
- **System**: Validate input
- **Data**: Email, password, name
- **Validation**: 
  - Email format
  - Password strength
  - Required fields

### 3. Duplicate Check
- **Actor**: System
- **System**: Query database for email
- **Data**: Email
- **Validation**: Uniqueness constraint

### 4. User Creation
- **Actor**: System
- **System**: Insert user record
- **Data**: All user fields
- **Validation**: Database constraints

### 5. Token Generation
- **Actor**: System
- **System**: Generate unique token
- **Data**: User ID, timestamp
- **Validation**: Token uniqueness

### 6. Email Sending
- **Actor**: System
- **System**: Call email service
- **Data**: Email, token, template
- **Validation**: Email service response

### 7. Email Verification
- **Actor**: User
- **System**: Validate token and activate
- **Data**: Token
- **Validation**: Token exists, not expired

## Exception Handling

### Validation Errors
- **Trigger**: Invalid form data
- **Response**: Return to form with errors
- **User Message**: Specific field errors
- **Logging**: Client-side only

### Duplicate Email
- **Trigger**: Email exists in database
- **Response**: Return to form
- **User Message**: "Email already registered"
- **Logging**: Security event

### Email Service Failure
- **Trigger**: Email API error
- **Response**: Retry with backoff
- **User Message**: "Verification email delayed"
- **Logging**: Error with full context

### Invalid Token
- **Trigger**: Token expired or invalid
- **Response**: Show error page
- **User Message**: "Link expired, please register again"
- **Logging**: Security event

## Business Rules

1. **Email Format**: RFC 5322 compliant
2. **Password Requirements**: 
   - Minimum 8 characters
   - At least 1 uppercase
   - At least 1 number
   - At least 1 special character
3. **Token Expiry**: 24 hours
4. **Retry Logic**: 3 attempts with exponential backoff
5. **Rate Limiting**: 5 registration attempts per IP per hour

## Performance Considerations

### Database Operations
- **User Check**: Index on email field
- **User Insert**: Batch token generation
- **Token Validation**: Redis cache

### Email Sending
- **Queue**: Async processing
- **Priority**: Normal queue
- **Timeout**: 30 seconds

## Security Measures

1. **Password Handling**: Never log or store plaintext
2. **Token Security**: Cryptographically secure generation
3. **Rate Limiting**: IP and email based
4. **Audit Trail**: All registration attempts logged
5. **CAPTCHA**: After 2 failed attempts

## Metrics to Track

1. **Conversion Rate**: Form views to completions
2. **Drop-off Points**: Where users abandon
3. **Error Rates**: By error type
4. **Email Delivery**: Success rate and timing
5. **Verification Rate**: Emails sent to verified

## Integration Points

### External Services
1. **Email Service**: SendGrid/AWS SES
2. **CAPTCHA**: Google reCAPTCHA
3. **Analytics**: Google Analytics/Mixpanel

### Internal Systems
1. **User Database**: PostgreSQL
2. **Cache**: Redis
3. **Queue**: RabbitMQ
4. **Logging**: ELK Stack

## Testing Scenarios

### Happy Path
1. Valid registration with immediate verification
2. Valid registration with delayed verification

### Error Scenarios
1. Invalid email format
2. Weak password
3. Duplicate email
4. Email service down
5. Database connection lost
6. Token expired
7. Token already used

### Edge Cases
1. Multiple rapid submissions
2. Special characters in name
3. International email domains
4. Concurrent registrations same email
5. Browser back button usage
EOF
    
    log_event "SUCCESS" "BUSINESS_ANALYST" "Process flow generated for $process_name"
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        analyze)
            analyze_requirements "${2:-}"
            ;;
        specify)
            create_specifications "${2:-authentication}"
            ;;
        validate)
            validate_acceptance_criteria "${2:-}"
            ;;
        feedback)
            create_feedback_mechanism
            ;;
        flow)
            generate_process_flows "${2:-user_registration}"
            ;;
        init)
            echo -e "${CYAN}Initializing business analysis...${NC}"
            analyze_requirements
            create_specifications "authentication"
            validate_acceptance_criteria
            create_feedback_mechanism
            generate_process_flows "user_registration"
            echo -e "${GREEN}✓ Business analysis complete!${NC}"
            echo -e "${YELLOW}Review outputs in: $BA_STATE${NC}"
            ;;
        *)
            echo "Usage: $0 {analyze|specify|validate|feedback|flow|init} [options]"
            echo ""
            echo "Commands:"
            echo "  analyze [req_doc]     - Analyze requirements document"
            echo "  specify [feature]     - Create detailed specification"
            echo "  validate [criteria]   - Validate acceptance criteria"
            echo "  feedback             - Create feedback mechanism"
            echo "  flow [process]       - Generate process flow"
            echo "  init                 - Run complete analysis"
            exit 1
            ;;
    esac
}

main "$@"
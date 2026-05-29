---
name: jira-implement
description: "Feature implementation workflow for Jira stories and tasks. Automates requirement analysis, architecture planning, git branch creation, and AI-powered implementation strategies. Use for feature development, enhancements, and new functionality tasks."
---

# Jira Feature Implementation Workflow

Automated workflow for implementing features and enhancements tracked in Jira. Combines issue analysis, architecture planning, and AI-assisted implementation strategy generation with supervised execution.

## Overview

The jira-implement workflow transforms Jira features and tasks into actionable implementation plans through:

1. **Requirement Analysis**: Extract acceptance criteria, dependencies, and technical constraints from issue
2. **Architecture Planning**: AI agent generates component breakdown and integration strategy
3. **Implementation Strategy**: Create step-by-step implementation plan with test coverage
4. **Supervised Execution**: Execute plan with human oversight at each step
5. **Plan Persistence**: Save implementation strategy for future reference

Use this workflow to:
- Convert feature requirements into concrete architecture decisions
- Generate testable implementation plans before coding
- Maintain decision history with markdown plan files
- Integrate naturally with existing git/CI workflows

## Prerequisites

- `jira` CLI must be installed and configured (`jira init` completed)
- `git` must be installed (for branch creation)
- `JIRA_API_TOKEN` environment variable must be set
- Access to AI agent for implementation planning (Claude, OpenAI, or similar)
- `jira-common` skill installed (for utility functions)

## Quick Start

### Basic Feature Implementation

```bash
# Interactive workflow (prompts for each step)
./implement-workflow.sh

# Implement specific story
./implement-workflow.sh STORY-456

# Implement with auto-approval (skips confirmation prompts)
./implement-workflow.sh STORY-456 --auto-approve
```

## Workflow Steps

### Step 1: Issue Analysis

Fetch and analyze the Jira story/task:

```bash
jira issue view STORY-456 --plain
```

**Extracted information**:
- Summary and description
- Acceptance criteria (from description or AC field)
- Story points and priority
- Labels and components
- Linked issues (dependencies)
- Attachments (design docs, specs)

### Step 2: Architecture Planning with AI

Delegate to AI agent to generate implementation plan:

```bash
/jira-implement-plan STORY-456
```

**AI generates**:
- Component breakdown (what needs to be created/modified)
- Integration architecture (how components interact)
- Technology choices with justification
- Testing strategy (unit, integration, e2e)
- Risk assessment and mitigations
- Acceptance criteria mapping

### Step 3: Create Implementation Branch

Use jira-common utility to create feature branch:

```bash
branch=$(path/to/jira-common/scripts/create-branch.sh --issue STORY-456)
echo "Working on: $branch"
```

**Branch naming**:
- Story/Task → `feature/STORY-456-issue-slug`
- Bug → `bugfix/BUG-123-issue-slug`

### Step 4: Save Implementation Plan

Persist AI-generated plan as markdown:

```bash
plan_file=$(path/to/jira-common/scripts/save-plan.sh \
  --issue STORY-456 \
  --type implement \
  --content "$implementation_plan")

echo "Plan saved: $plan_file"
```

**File structure** (plans/STORY-456-implement-TIMESTAMP.md):
```markdown
---
issue: STORY-456
type: implement
timestamp: 2024-02-03T15:42:30Z
branch: feature/story-456-implement-user-auth
user: engineer
---

# Implementation Plan

## Architecture Overview
...

## Component Breakdown
...
```

### Step 5: Supervised Step Execution

Execute implementation plan with AI guidance:

1. Review plan sections
2. For each implementation step:
   - Get AI guidance on specific implementation
   - Execute code changes
   - Run tests
   - Commit changes with descriptive messages
3. Track progress in plan file
4. Handle errors with jira-common utilities

**Error handling**:

```bash
if ! npm test; then
  path/to/jira-common/scripts/post-error-to-jira.sh \
    --issue STORY-456 \
    --step "Unit tests" \
    --error-log test-output.log \
    --auto-post
  exit 1
fi
```

## Usage Examples

### Example 1: Implement User Authentication Feature

```bash
# Start workflow
./implement-workflow.sh STORY-123

# Workflow prompts for:
# 1. Download attachments? (design docs, wireframes)
# 2. Create feature branch? (confirms branch name)
# 3. Invoke AI planner? (generates implementation plan)
# 4. Save plan to file? (creates ./plans/STORY-123-implement-*.md)
# 5. Start implementation? (executes plan with supervision)

# Sample AI-generated plan:
# - Create AuthService class
# - Add JWT token validation middleware
# - Implement login/logout endpoints
# - Add authentication UI components
# - Create unit tests for auth logic
# - Add integration tests
# - Update documentation
```

### Example 2: Implement Dashboard Enhancement

```bash
# Quick implementation for high-priority enhancement
./implement-workflow.sh STORY-789 --auto-approve

# With auto-approve:
# - Downloads all attachments automatically
# - Creates branch without confirmation
# - Invokes AI planner
# - Saves plan automatically
# - Waits for user input at each implementation step
```

### Example 3: Implement API Endpoint

```bash
# Check what the issue requires
jira issue view STORY-456

# Custom implementation
branch=$(path/to/jira-common/scripts/create-branch.sh --issue STORY-456)

# Get AI guidance
echo "Generating implementation plan for REST API endpoint..." 
# Delegate to AI planning agent

# Save plan
plan=$(path/to/jira-common/scripts/save-plan.sh \
  --issue STORY-456 \
  --type implement)
```

## AI Delegation: Implementation Planning

Delegate implementation planning to AI agent:

```bash
/jira-implement-plan STORY-456
```

**What AI analyzes**:
- Jira issue details and acceptance criteria
- Existing codebase patterns (if available)
- Technology stack and frameworks
- Related issues and dependencies

**What AI generates**:
1. Architecture overview (system design decisions)
2. Component breakdown (files/classes to create/modify)
3. Integration points (how components connect)
4. Implementation steps (ordered, testable, incrementa)
5. Test coverage plan (unit, integration, e2e)
6. Risk assessment (potential issues and mitigations)

## Plan Format

### Example Implementation Plan

```markdown
---
issue: STORY-456
type: implement
timestamp: 2024-02-03T15:42:30Z
branch: feature/story-456-implement-user-auth
user: engineer
---

# Implementation Plan: User Authentication

## Acceptance Criteria Mapping

- [ ] Users can register with email/password
- [ ] Users can login with valid credentials
- [ ] Sessions persist across page reloads
- [ ] Users can logout
- [ ] Password reset flow works

## Architecture Overview

**Technology Stack**:
- Backend: Express.js with Passport.js authentication
- Frontend: React with React Router v6
- Database: PostgreSQL with Prisma ORM
- Security: JWT tokens, bcrypt password hashing

**Key Design Decisions**:
1. **JWT over Sessions**: Stateless auth for scalability
2. **Separate Auth Service**: Reusable across features
3. **OAuth Ready**: Design supports future social login
4. **Password Reset Token**: Secure, time-limited recovery

## Component Breakdown

### Backend Components

1. **AuthService** (`src/services/auth.ts`)
   - User registration with validation
   - Password hashing with bcrypt
   - JWT token generation/verification
   - Email verification flow

2. **Auth Routes** (`src/routes/auth.ts`)
   - POST /auth/register
   - POST /auth/login
   - POST /auth/logout
   - POST /auth/refresh-token
   - POST /auth/request-reset
   - POST /auth/reset-password

3. **Auth Middleware** (`src/middleware/auth.ts`)
   - JWT verification
   - User context injection
   - Protected route handling

### Frontend Components

1. **LoginForm** (`src/components/LoginForm.tsx`)
   - Email/password inputs
   - Form validation
   - Error handling
   - Remember me option

2. **RegisterForm** (`src/components/RegisterForm.tsx`)
   - Email/password/confirm inputs
   - Validation rules
   - Terms acceptance
   - Email verification flow

3. **ProtectedRoute** (`src/components/ProtectedRoute.tsx`)
   - Route guard component
   - Redirect to login if unauthorized
   - Token refresh handling

4. **AuthContext** (`src/context/AuthContext.tsx`)
   - Global auth state
   - User info persistence
   - Token management

## Implementation Steps

### Phase 1: Backend API (Estimated: 4 hours)

**Step 1.1: Create User Model**
- [ ] Create `src/models/User.ts`
- [ ] Define Prisma schema: email, password_hash, created_at, verified
- [ ] Add database migration
- [ ] Command: `npx prisma migrate dev --name create_users_table`

**Step 1.2: Implement AuthService**
- [ ] Create `src/services/auth.ts`
- [ ] Add registration function (validate email, hash password, create user)
- [ ] Add login function (verify credentials, generate JWT)
- [ ] Add JWT verification function
- [ ] Test with mock database

**Step 1.3: Create Auth Routes**
- [ ] Create `src/routes/auth.ts`
- [ ] Implement POST /auth/register endpoint
- [ ] Implement POST /auth/login endpoint
- [ ] Add input validation with joi/zod
- [ ] Add error handling

**Step 1.4: Auth Middleware**
- [ ] Create `src/middleware/auth.ts`
- [ ] Implement JWT verification middleware
- [ ] Add user context injection
- [ ] Test with protected routes

**Tests**:
```bash
npm test -- auth.service.test.ts
npm test -- auth.routes.test.ts
```

### Phase 2: Frontend Implementation (Estimated: 3 hours)

**Step 2.1: Create AuthContext**
- [ ] Create `src/context/AuthContext.tsx`
- [ ] Manage auth state (user, token, loading)
- [ ] Add localStorage persistence
- [ ] Add auto-login on app load

**Step 2.2: Login Form Component**
- [ ] Create `src/components/LoginForm.tsx`
- [ ] Implement form validation
- [ ] Call /auth/login endpoint
- [ ] Handle success/error states
- [ ] Redirect on success

**Step 2.3: Register Form Component**
- [ ] Create `src/components/RegisterForm.tsx`
- [ ] Email/password/confirm validation
- [ ] Call /auth/register endpoint
- [ ] Email verification prompt

**Step 2.4: Route Protection**
- [ ] Create `src/components/ProtectedRoute.tsx`
- [ ] Wrap protected pages
- [ ] Auto-redirect to login if unauthorized
- [ ] Handle token refresh

**Tests**:
```bash
npm test -- LoginForm.test.tsx
npm test -- ProtectedRoute.test.tsx
```

### Phase 3: Integration & Polish (Estimated: 2 hours)

**Step 3.1: API Integration Testing**
- [ ] Test registration → login flow
- [ ] Test session persistence
- [ ] Test logout behavior
- [ ] Test invalid credentials handling

**Step 3.2: Security Review**
- [ ] Verify password hashing
- [ ] Check HTTPS requirement
- [ ] Validate JWT expiration
- [ ] Test CSRF protection

**Step 3.3: Documentation**
- [ ] API documentation in README
- [ ] Setup instructions
- [ ] Environment variables guide

## Test Coverage Plan

### Unit Tests (Backend)
```
- AuthService
  - Password hashing verification
  - JWT generation/verification
  - User validation rules
  
- Email validation
- Token expiration handling
```

### Unit Tests (Frontend)
```
- LoginForm component
  - Form validation
  - API call handling
  - Error display
  
- AuthContext
  - State updates
  - localStorage sync
```

### Integration Tests
```
- Complete auth flow: register → email verify → login → logout
- Session persistence across page reloads
- Protected route access control
- Token refresh mechanism
```

### E2E Tests (Cypress/Playwright)
```
- User registration with email
- User login with credentials
- Logout functionality
- Password reset flow
- Unauthorized access redirect
```

## Risk Assessment

### Risk 1: Password Security
**Issue**: Passwords stored insecurely
**Mitigation**: 
- Use bcrypt with work factor 12+
- Never log passwords
- HTTPS only transmission

### Risk 2: Token Hijacking
**Issue**: Stolen JWT tokens used maliciously
**Mitigation**:
- Short expiration (15 min access, refresh token)
- Secure cookie flags (httpOnly, Secure)
- Token refresh endpoint

### Risk 3: SQL Injection
**Issue**: User input directly in queries
**Mitigation**:
- Use parameterized queries (Prisma)
- Input validation with joi/zod

### Risk 4: Email Verification Bypass
**Issue**: Users access unverified accounts
**Mitigation**:
- Require email verification before full access
- Time-limited verification tokens (10 min)

## Acceptance Criteria Validation

After implementation, verify:

- [ ] Users can register with valid email/password
- [ ] Invalid emails rejected
- [ ] Weak passwords rejected
- [ ] Registered users can login
- [ ] Invalid credentials show error
- [ ] Valid login creates session
- [ ] Session persists across refreshes
- [ ] Logout clears session
- [ ] Unverified emails cannot access full app
- [ ] Password reset generates recovery email
- [ ] Recovery token valid for 10 minutes
- [ ] All endpoints require HTTPS in production
- [ ] Passwords hashed with bcrypt
- [ ] JWT tokens expire after 15 minutes
- [ ] Refresh tokens valid for 7 days

## Success Criteria

✅ Implementation complete when:
1. All API endpoints tested and working
2. Frontend components integrated with backend
3. 80%+ test coverage on auth logic
4. E2E tests passing (registration, login, logout)
5. Security review completed
6. Documentation updated
7. Code merged to main branch
```

## Supervised Step Execution

Implementation follows the plan with human supervision:

### For Each Implementation Step

1. **Review Step**: Read plan section carefully
2. **Get Guidance**: Ask AI for specific implementation help
3. **Implement**: Write code, create files
4. **Test**: Run relevant tests
5. **Commit**: Save changes with descriptive message
6. **Iterate**: Move to next step or refine current

### Example Execution Flow

```bash
# Step 1.1: Create User Model
# Read plan section for User model requirements
# Ask AI: "Help me create the Prisma User model based on auth requirements"
# Create src/models/User.ts
# Run: npx prisma migrate dev
# Commit: git commit -m "Create User model with email and password fields"

# Step 1.2: Implement AuthService
# Read plan section for AuthService requirements
# Ask AI: "Implement the registration function with password hashing"
# Write src/services/auth.ts
# Run: npm test -- auth.service.test.ts
# Commit: git commit -m "Implement AuthService with register/login functions"

# Continue through all steps...
```

### Handling Implementation Errors

If an implementation step fails:

```bash
# Capture error details
npm test 2>&1 | tee test-error.log

# Post to Jira for tracking
path/to/jira-common/scripts/post-error-to-jira.sh \
  --issue STORY-456 \
  --step "Unit tests for AuthService" \
  --error-log test-error.log

# Fix issue and retry step
# Re-run tests
# Commit fix: git commit -m "Fix test error in AuthService"
```

## Workflow Management

### Create Implementation Directory

```bash
# Create local project directory for implementation
mkdir -p implementation/STORY-456
cd implementation/STORY-456

# Initialize git (if not in repo)
git init
```

### Track Implementation Progress

Update plan file as implementation progresses:

```bash
# After completing Phase 1
# Edit ./plans/STORY-456-implement-*.md
# Mark completed steps: [x] instead of [ ]
# Add notes on any deviations from plan
# Commit: git add plans/ && git commit -m "Update implementation plan - Phase 1 complete"
```

### Integration with CI/CD

```bash
# Before pushing to remote
npm test          # Run all tests
npm run lint      # Check code quality
npm run build     # Build for production

# Push changes
git push origin feature/STORY-456

# Create PR with plan reference
# PR description includes: "Implementation plan: ./plans/STORY-456-implement-*.md"
```

## Troubleshooting

### Issue: "jira CLI not found"

**Solution**:
```bash
# Install jira CLI
go install github.com/go-jira/jira/cmd/jira@latest

# Configure
jira init

# Verify
jira me
```

### Issue: "Not in a git repository"

**Solution**:
```bash
# Initialize git in project
git init

# Or navigate to existing repo
cd /path/to/repo

# Verify
git rev-parse --git-dir
```

### Issue: "AI planner not accessible"

**Solution**:
```bash
# Verify AI agent is running
# Check /jira-implement-plan command is available
# Verify API token/credentials if using external AI

# For local: ensure Claude instance is available
# For external: check API keys in environment
```

### Issue: "Branch creation fails"

**Solution**:
```bash
# Check uncommitted changes
git status

# Stash changes if needed
git stash

# Try branch creation again
path/to/jira-common/scripts/create-branch.sh --issue STORY-456
```

### Issue: "Cannot save plan file"

**Solution**:
```bash
# Check if plans directory exists
mkdir -p ./plans

# Check write permissions
touch ./plans/test.md && rm ./plans/test.md

# Verify current directory
pwd

# Try saving plan again
path/to/jira-common/scripts/save-plan.sh --issue STORY-456 --type implement
```

## Integration with jira-common Skill

The jira-implement workflow uses these jira-common utilities:

### create-branch.sh

Creates feature branch from story:

```bash
branch=$(path/to/jira-common/scripts/create-branch.sh --issue STORY-456)
# Output: feature/story-456-implement-user-auth
```

### save-plan.sh

Saves implementation strategy:

```bash
path/to/jira-common/scripts/save-plan.sh \
  --issue STORY-456 \
  --type implement \
  --content "$ai_generated_plan"
```

### post-error-to-jira.sh

Logs implementation errors to issue:

```bash
path/to/jira-common/scripts/post-error-to-jira.sh \
  --issue STORY-456 \
  --step "Phase 2: Frontend implementation" \
  --error "Login component test failures" \
  --auto-post
```

### download-all-attachments.sh

Retrieves design docs and specifications:

```bash
files=$(path/to/jira-common/scripts/download-all-attachments.sh --issue STORY-456)
# Use attachments to inform implementation decisions
```

## Best Practices

### Before Starting Implementation

1. **Review acceptance criteria** thoroughly
2. **Download and examine** any attached specs/designs
3. **Understand dependencies** - linked issues, API contracts
4. **Identify tech stack** - frameworks, libraries, patterns
5. **Create implementation branch** with clear naming

### During Implementation

1. **Follow the plan** - implement steps in order
2. **Test incrementally** - don't wait until end
3. **Commit frequently** - atomic commits with clear messages
4. **Document decisions** - add comments explaining why
5. **Handle errors gracefully** - post errors to Jira

### After Implementation

1. **Verify acceptance criteria** - check each requirement
2. **Run full test suite** - ensure nothing broke
3. **Code review** - get peer feedback
4. **Update documentation** - API docs, setup guide
5. **Merge and deploy** - follow CI/CD process

## Advanced Features

### Custom Implementation Plans

For complex features, customize AI planner prompt:

```bash
# Provide additional context to AI planner
export IMPL_CONTEXT="Database must support 100k+ users with sub-100ms queries"
export IMPL_CONSTRAINTS="Cannot modify existing User schema"

# Run planner with constraints
/jira-implement-plan STORY-456
```

### Implementation Checkpoints

Save progress at key points:

```bash
# After Phase 1 complete
git commit -m "Phase 1 complete: Auth backend API implemented"

# Create checkpoint in plan
echo "## Checkpoint 1: Backend Complete" >> ./plans/STORY-456-implement-*.md

# After Phase 2 complete
git commit -m "Phase 2 complete: Frontend components integrated"
```

### Revert Strategy

If implementation goes off track:

```bash
# Check git log for previous checkpoints
git log --oneline

# Revert to last known good state
git reset --hard <commit-hash>

# Update plan file with notes
echo "Reverted to commit $commit_hash - trying different approach" >> plan.md
```

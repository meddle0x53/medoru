---
description: Medoru development workflow - iteration-based development with code reviews and continuity logging
---

# Medoru Development Workflow

## Overview
This skill defines the development workflow for Medoru 0.1.0 and beyond. It ensures consistency across iterations and enables seamless continuity when new instances take over.

## Iteration-Based Development

### Structure
Each iteration follows this pattern:
1. **Plan** - Review the iteration tasks with the user
2. **Implement** - Write code following Medoru conventions
3. **Test** - Run tests, fix failures, ensure quality
4. **Log** - Document what was done (see Logging section below)
5. **Review** - User conducts code review
6. **Refine** - Address review feedback (if any)
7. **Complete** - Mark iteration as done, proceed to next

### Code Review Process
After EACH iteration:
- User reviews the code changes
- User may provide feedback, request changes, or approve
- If changes requested: implement fixes, re-log, re-review
- If approved: proceed to next iteration

**Important**: NEVER proceed to the next iteration until the user explicitly approves the current one after review.

## Continuity Logging

### Purpose
Logs enable a new instance of me to understand:
- What was completed in each iteration
- Current project state
- Any decisions made or context gained
- What's next

### Log Location
All logs are stored in: `.agents/logs/`

### Log File Naming
- Format: `ITERATION-{NN}-{short-description}.md`
- Example: `ITERATION-01-oauth-auth.md`

### Log Template
Each log file MUST include:

```markdown
# Iteration {NN}: {Title}

**Status**: COMPLETED / IN_PROGRESS  
**Date**: YYYY-MM-DD  
**Reviewed By**: {user}  
**Approved**: YES / PENDING CHANGES

## What Was Implemented
- List of completed tasks
- Files created/modified

## Key Decisions
- Any architectural decisions made
- Workarounds or trade-offs

## Schema Changes
- New tables/columns
- Migration names

## LiveViews/Routes Added
- Route paths and their LiveView modules

## Known Issues / TODOs
- Anything left for future iterations

## Next Steps
- What the next iteration should focus on

## Running State
- Any running processes, states to be aware of
```

### Index File
Maintain `.agents/logs/INDEX.md` with a summary:

```markdown
# Medoru Development Logs

## Iterations
| # | Title | Status | Date |
|---|-------|--------|------|
| 1 | OAuth & Accounts | COMPLETED | 2026-03-05 |
| 2 | Kanji Content | IN_PROGRESS | - |

## Current State
- Last completed: Iteration 1
- Next: Iteration 2 - Kanji & Readings
```

## Pre-Iteration Checklist
Before starting a new iteration, always:

1. Read `.agents/logs/INDEX.md` to understand current state
2. Read the last completed iteration log for context
3. Read `.agents/skills/medoru/SKILL.md` for technical conventions
4. Confirm with user which iteration to work on
5. Verify no pending review from previous iteration

## Post-Iteration Checklist
After completing an iteration:

1. Run full test suite (`mix test`)
2. Run quality checks (`mix precommit`)
3. Write iteration log to `.agents/logs/`
4. Update `.agents/logs/INDEX.md`
5. Present summary to user for review
6. Wait for approval before proceeding

## Communication Template

### Starting an Iteration
```
Starting **Iteration {N}: {Title}**

Tasks in this iteration:
- [ ] Task 1
- [ ] Task 2
...

I'll begin implementation now.
```

### Completing an Iteration
```
**Iteration {N}: {Title}** - COMPLETE ✅

Summary:
- Files created: X
- Files modified: Y
- Tests passing: Z/Z

**Iteration Log**: `.agents/logs/ITERATION-{NN}-{desc}.md`

Please review the changes. Once approved, I'll proceed to the next iteration.
```

## Workflow Boundaries

- ✅ **Always**: Wait for user review and approval between iterations
- ✅ **Always**: Write detailed logs after each iteration
- ✅ **Always**: Update INDEX.md with current state
- ⚠️ **Ask first**: If user wants to skip a review or combine iterations
- 🚫 **Never**: Start a new iteration before previous is approved
- 🚫 **Never**: Delete or overwrite iteration logs

## Context Transfer

If a new instance takes over:
1. Read `.agents/logs/INDEX.md`
2. Read the most recent completed iteration log
3. Read any IN_PROGRESS log (if applicable)
4. Ask user for confirmation on next steps
5. Continue from where previous instance left off

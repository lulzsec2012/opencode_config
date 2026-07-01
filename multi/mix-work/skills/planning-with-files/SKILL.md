---
name: planning-with-files
description: >-
  Create, read, and manage structured plan files for complex tasks. Use this skill whenever
  the user needs to break down a complex task into actionable steps, create a work plan,
  analyze requirements before implementation, or document a multi-step development strategy.
  Supports multiple languages (English, Arabic, German, Spanish, Chinese). Triggers:
  "make a plan", "create a plan file", "break this down", "plan this feature",
  "write a plan for", "planning", "work plan", "implementation plan", "step-by-step plan".
---

# planning-with-files

Create clear, actionable plan files that break complex work into manageable steps.

## When to Use

- User asks to create a plan before implementing
- Task has 5+ steps or involves multiple modules
- Need to document a development approach
- User wants to organize work into phases
- Requirements analysis for a new feature

## Plan File Structure

Plan files live in `.omo/plans/<plan-name>.md` with this structure:

```markdown
# Plan: <Title>

## Goal
<one-line description of what this plan achieves>

## Prerequisites
- <conditions that must be true before starting>

## Steps
1. **Step title**
   - What: <what to do>
   - Why: <why this step exists>
   - Files: <files to modify/create>
   - Verify: <how to confirm this step is done>

2. **Step title**
   - ...

## Risks
- <potential issues and mitigations>

## Done Criteria
- [ ] <condition 1>
- [ ] <condition 2>
```

## Workflow

### Phase 1: Understand
1. Read the user's request fully before planning
2. Ask clarifying questions if scope is ambiguous
3. Identify implicit requirements and edge cases

### Phase 2: Plan
1. Break the work into atomic, verifiable steps
2. Each step must be completable independently
3. Order steps by dependency (what must come first)
4. Include verification criteria for each step
5. Note any risks or unknowns

### Phase 3: Write
1. Write the plan to `.omo/plans/<plan-name>.md`
2. Use the structure above
3. Use the user's language (Chinese by default)
4. Present the plan for review before execution starts

## Plan Quality Checklist

- [ ] Each step has a clear "what" and "why"
- [ ] Steps are ordered by dependency
- [ ] Verification criteria are concrete (not "test it")
- [ ] Risks are identified
- [ ] Done criteria are measurable
- [ ] Plan is stored in `.omo/plans/`

## Multi-Language Support

This skill natively supports:
- `zh` / `zht` — Chinese (Simplified / Traditional) plan files
- `en` — English
- `ar` — Arabic
- `de` — German
- `es` — Spanish

Detect the user's language from their request and write the plan in that language.

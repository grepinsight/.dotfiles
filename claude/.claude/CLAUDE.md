## IMPORTANT


- For WORK related general notes(infrastructure, internal), store them in ${OBSIDIAN_VAULT_WORK}
- For WORK related personal project notes, store them in ${OBSIDIAN_VAULT_WORK_PERSONAL}
- For NON-WORK related personal/general notes, store them in ${OBSIDIAN_VAULT}
- For project specific work (i.e. you are in a directory that's none of above, write the notes there

- Do not mention Claude Code authorship in commit messages OR PR messages

## Note-Taking Guidelines

### Keep Notes Focused and Concise

Notes (Obsidian, Evernote, etc.) should **not be extremely long**. Long notes are:
- Hard to navigate
- Difficult to update
- Overwhelming to read
- Poor for cross-referencing

### Break Apart Long Notes

**When a note exceeds ~300-400 lines:**
1. Split into focused, single-topic notes
2. Create an index/overview note with links
3. Use clear, descriptive titles for each note
4. Link related notes together

**Example structure:**
```
Main Topic.md (index with links)
├── Topic - Getting Started.md
├── Topic - Core Concepts.md
├── Topic - Advanced Features.md
└── Topic - Troubleshooting.md
```

### Benefits of Shorter Notes

- **Easier to find** - Specific topics are discoverable
- **Easier to maintain** - Update one topic without scrolling
- **Better linking** - Reference precise content
- **Less cognitive load** - Focused reading experience
- **Better for AI context** - Easier to load relevant information

## Philosophy

### Core Beliefs
- **Incremental progress over big bangs** - Small changes that compile and pass tests
- **Learning from existing code** - Study and plan before implementing
- **Pragmatic over dogmatic** - Adapt to project reality
- **Clear intent over clever code** - Be boring and obvious

### Simplicity Means

- Single responsibility per function/class
- Avoid premature abstractions
- No clever tricks - choose the boring solution
- If you need to explain it, it's too complex

## Process

### 1. Planning & Staging

Break complex work into 3-5 stages. Document in `IMPLEMENTATION_PLAN.md`:

```markdown
## Stage N: [Name]
**Goal**: [Specific deliverable]
**Success Criteria**: [Testable outcomes]
**Tests**: [Specific test cases]
**Status**: [Not Started|In Progress|Complete]
```
- Update status as you progress
- Remove file when all stages are done

### 2. Implementation Flow

1. **Understand** - Study existing patterns in codebase
2. **Test** - Write test first (red)
3. **Implement** - Minimal code to pass (green)
4. **Refactor** - Clean up with tests passing
5. **Commit** - With clear message linking to plan


## Technical Standards

### Architecture Principles

- **Composition over inheritance** - Use dependency injection
- **Interfaces over singletons** - Enable testing and flexibility
- **Explicit over implicit** - Clear data flow and dependencies
- **Test-driven when possible** - Never disable tests, fix them

### Code Quality

- **Every commit must**:
  - Compile successfully
  - Pass all existing tests
  - Include tests for new functionality
  - Follow project formatting/linting

- **Before committing**:
  - Run formatters/linters
  - Self-review changes
  - Ensure commit message explains "why"

### Git Commits

- **Use conventional commit format**: `type(scope): description`
  - Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
  - Example: `feat(auth): add password reset functionality`
  - Example: `fix(api): handle null response from database`

- **Commit message structure**:
  ```
  type(scope): short summary (50 chars max)

  Optional detailed explanation of why this change
  was necessary and what problem it solves.

  Closes #123
  ```

- **Commit incrementally**: Small, logical commits that compile and pass tests

### Frontend UX

- **Guard destructive actions with confirmation modals** - Any operation that deletes data, cancels a process, removes access, or is otherwise irreversible must require explicit user confirmation via a modal dialog
- Confirmation modals should clearly describe the consequences (what will be deleted/changed and that it cannot be undone)
- Use distinct button labels (e.g., "Keep Import" / "Cancel Import") rather than generic "OK" / "Cancel"

### Error Handling

- Fail fast with descriptive messages
- Include context for debugging
- Handle errors at appropriate level
- Never silently swallow exceptions

### Secrets & Credentials

- **Never display raw secret values** in terminal output, logs, or commits
- To inspect which keys are present in a `.env` without revealing values:
  ```bash
  # Show key names only — mask values
  grep -E '^(SLACK_|OPENAI_|AWS_|KEY_|TOKEN_|SECRET_)' .env | sed 's/=.*/=...'
  ```
- Secrets files (`.env.secret`, `.envrc`) must be in `.gitignore`; `.env` too unless
  the project explicitly commits it for non-secret config (use `.env.secret` for actual
  secrets in that case)

## Decision Framework

When multiple valid approaches exist, choose based on:

1. **Testability** - Can I easily test this?
2. **Readability** - Will someone understand this in 6 months?
3. **Consistency** - Does this match project patterns?
4. **Simplicity** - Is this the simplest solution that works?
5. **Reversibility** - How hard to change later?

## Project Integration

### Learning the Codebase

- Find 3 similar features/components
- Identify common patterns and conventions
- Use same libraries/utilities when possible
- Follow existing test patterns

### Tooling

- Use project's existing build system
- Use project's test framework
- Use project's formatter/linter settings
- Don't introduce new tools without strong justification

## Quality Gates

### Definition of Done

- [ ] Tests written and passing
- [ ] Code follows project conventions
- [ ] No linter/formatter warnings
- [ ] Commit messages are clear
- [ ] Implementation matches plan
- [ ] No TODOs without issue numbers

### Test Guidelines

- Test behavior, not implementation
- One assertion per test when possible
- Clear test names describing scenario
- Use existing test utilities/helpers
- Tests should be deterministic

## Important Reminders

**NEVER**:
- Use `--no-verify` to bypass commit hooks
- Disable tests instead of fixing them
- Commit code that doesn't compile
- Make assumptions - verify with existing code

**ALWAYS**:
- Commit working code incrementally
- Update plan documentation as you go
- Learn from existing implementations
- Stop after 3 failed attempts and reassess

<!-- 7ec47a1a-b3f9-4982-a122-1a0904969b65 b448684b-abb8-4e5b-ba92-6f126e6e3e7d -->
# Auto-Updating Changelog System

## Overview

Implement a git pre-commit hook that automatically analyzes staged code changes and generates structured changelog entries. Aurora will also have access to git commit history to reference past updates and link changelog entries to actual code changes.

## Implementation Plan

### Phase 1: Create Changelog Generator Script

**File:** `scripts/generate_changelog.swift` (or Python alternative)

Script that:
- Reads git diff for staged changes using `git diff --cached`
- Parses Swift files for patterns:
  - New service files (`*Service.swift`)
  - New public functions/methods (`func`, `public func`, `actor`)
  - Modified system prompts (`buildSystemPrompt`)
  - New models/types (`struct`, `class`, `enum`)
  - Capability comments (`// NEW:`, `// Capability:`, `// Feature:`)
- Generates structured JSON entries with:
  - Auto-generated UUID
  - Current timestamp (ISO 8601)
  - Extracted feature name from file/function names
  - Description from code comments or function signatures
  - Appropriate change type (added/modified/improved/fixed)
  - User-facing flag based on public API or comments
  - Tags extracted from file paths and comments
- Merges new entries with existing `aurora_changelog.json`
- Preserves existing entries and maintains chronological order
- Outputs updated JSON to `FocusOS/aurora_changelog.json`

**Pattern Detection:**
- New files: `git diff --cached --name-status` → detect `A` (added)
- Modified files: Detect `M` (modified)
- Service detection: File path contains `*Service.swift`
- Function detection: Regex match `(public )?func|actor`
- Comment detection: Lines starting with `// NEW:`, `// Capability:`, `// Feature:`
- System prompt changes: File contains `buildSystemPrompt` and is modified

### Phase 2: Create Git Pre-Commit Hook

**File:** `.git/hooks/pre-commit`

Hook that:
- Runs `scripts/generate_changelog.swift` (or Python script)
- Checks if changelog.json was updated
- If updated, stages the updated file: `git add FocusOS/aurora_changelog.json`
- Allows commit to proceed
- After commit (via post-commit hook), updates changelog entries with commit hash

**File:** `.git/hooks/post-commit`

Hook that:
- Gets latest commit hash: `git rev-parse HEAD`
- Updates the most recent changelog entry with commit hash
- Links changelog entries to actual commits

### Phase 3: Add Commit Hash to Changelog Model

**File:** `FocusOS/Models/AuroraChangelog.swift`

Update `AuroraChangelogEntry` to include:
- `commitHash: String?` - Git commit hash linking to code changes
- Links changelog entries to actual git commits

### Phase 4: Add Git Commit History Access to Aurora

**File:** `FocusOS/Services/AuroraChangelogService.swift`

Add methods:
- `getCommitHistory(days: Int?) -> [GitCommit]` - Retrieve git commits
- `getCommitsForFeature(_ feature: String) -> [GitCommit]` - Find commits related to a feature
- `getCommitDetails(_ hash: String) -> GitCommit?` - Get detailed commit info
- `formatCommitHistory(_ commits: [GitCommit]) -> String` - Format for Aurora's context

**File:** `FocusOS/Models/GitCommit.swift` (new)

Model for git commit data:
- `hash: String` - Commit hash
- `date: Date` - Commit date
- `message: String` - Commit message
- `author: String` - Author name
- `files: [String]` - Changed files
- `changelogEntryId: UUID?` - Link to changelog entry if exists

### Phase 5: Integrate Git History into Aurora's Context

**File:** `FocusOS/Services/OllamaBridgeService.swift`

Update `buildSystemPrompt()` to:
- Query recent git commits (last 30 days) if available
- Include commit history context when relevant
- Add instructions: "You have access to git commit history. When discussing updates or changes, you can reference specific commits and their changes."

### Phase 6: Create Configuration File

**File:** `.changelog-config.json`

Configuration for:
- File paths to monitor (e.g., `FocusOS/Services/`, `FocusOS/Models/`)
- Pattern detection rules
- Feature name extraction patterns
- Default tags for file types
- User-facing detection rules

## Files to Create

**New Files:**
- `scripts/generate_changelog.swift` (or `scripts/generate_changelog.py`) - Main generator script
- `.git/hooks/pre-commit` - Git pre-commit hook
- `.git/hooks/post-commit` - Git post-commit hook (updates commit hashes)
- `FocusOS/Models/GitCommit.swift` - Git commit model
- `.changelog-config.json` - Configuration file

**Modified Files:**
- `FocusOS/Models/AuroraChangelog.swift` - Add commitHash field
- `FocusOS/Services/AuroraChangelogService.swift` - Add git history methods
- `FocusOS/Services/OllamaBridgeService.swift` - Integrate git history context
- `FocusOS/aurora_changelog.json` - Will be auto-updated

## Implementation Details

### Changelog Generator Script Structure

```swift
// Pseudo-code structure
1. Get staged files: git diff --cached --name-status
2. For each changed file:
   - Parse file content
   - Detect patterns (new services, functions, etc.)
   - Extract feature names and descriptions
   - Generate changelog entry
3. Load existing changelog.json
4. Merge new entries (prepend to maintain newest-first)
5. Update lastUpdated timestamp
6. Write updated JSON
```

### Git Hook Installation

The hooks will be created in `.git/hooks/` directory. They need to be:
- Executable (`chmod +x`)
- Handle errors gracefully (don't block commits if changelog generation fails)
- Provide clear error messages

### Git History Integration

Aurora will be able to:
- Query commits by date range
- Find commits related to specific features
- Reference commit hashes in responses
- Link changelog entries to actual code changes
- See what files changed in each commit

## Benefits

- Zero manual work - changelog updates automatically on commit
- Consistent formatting - always properly structured JSON
- Version tracking - automatic version detection from git tags
- Feature detection - catches new capabilities automatically
- Timestamp accuracy - exact time of commit
- Code linking - changelog entries linked to git commits
- Historical awareness - Aurora can reference past changes

## Usage

Once implemented:
1. Make code changes
2. Stage changes: `git add .`
3. Commit: `git commit -m "message"`
4. Pre-commit hook automatically generates changelog entries
5. Post-commit hook links entries to commit hash
6. Aurora can query git history to discuss updates

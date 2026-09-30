# Context Lifecycle, Migration, Compaction and Branch/Fork Summaries

The Context Spine follows one non-negotiable rule:

**Raw context is preserved. Derived summaries are additive.**

## Safe migration

bootstrap.ps1 automatically checks the legacy global OpenCode location:

    ~/.config/opencode/

When it exists, the installer calls Import-ExistingContext.ps1 before installing new OpenCode commands.

The importer:

1. leaves the source folders untouched;
2. creates a raw local snapshot under ~/.agent-context/imports/;
3. writes an audit manifest under ~/.agent-context/migrations/;
4. appends legacy MEMORY.md, lessons.md and preferences.md to their canonical Context Spine equivalents with SHA-256 import markers;
5. copies legacy memory/projects/** into ~/.agent-context/memory/projects/**;
6. never overwrites a conflicting project-memory file: a hash-suffixed imported copy is created instead.

Running the installer repeatedly is idempotent for unchanged imported files.

For another legacy location, pass one or more explicit paths:

    .\bootstrap.ps1 -Profile work -InstallOpenCode -ImportContextPath "C:\AI-Memory"

To deliberately skip legacy discovery:

    .\bootstrap.ps1 -Profile work -SkipLegacyImport

## Two layers of compaction

### Active OpenCode session

OpenCode V2 already performs context-window compaction automatically when a session approaches the selected model's context limit. Context Spine does not replace or disable that behavior.

This is the fast, in-session layer.

### Durable Context Spine history

Context Spine separately compacts older persisted handovers/session notes so future agents do not need to reload every old file.

Raw handovers/sessions live beneath:

    memory/projects/<project>/sessions/
    memory/projects/<project>/handovers/

Get-ContextMaintenance.ps1 estimates the uncompacted persisted-context load and creates a deterministic plan when the configured soft threshold is crossed. Defaults:

- trigger: 60,000 estimated tokens
- keep recent: 20,000 estimated tokens

The active coding agent performs the summary; no second model or external API is required. On the work profile, the already-approved OpenCode/GLM path can do this work.

Save-Compaction.ps1 verifies that every planned raw source still exists and has the same SHA-256 hash, validates the structured summary headings, saves the derived summary under context/compactions/<project>/, and records all source hashes in manifest.jsonl.

It does not delete or modify the raw files.

## Branch and session-fork summaries

The Pi-inspired branch-summary idea is broader than Git.

For an OpenCode/session fork or a deliberate alternative approach, ctx-branch-summary records the line of work being left so it remains retrievable after the fork.

For a Git branch switch, Get-BranchSummaryContext.ps1 can additionally record:

- from/to Git branches
- merge base
- commits unique to the branch being left
- changed files
- recent Context Spine session files

Save-BranchSummary.ps1 stores either kind of structured summary under:

    context/branches/<project>/

This remains additive: Git history, repository files, coding-session history and raw Context Spine memory are untouched.

## Retrieval

Use:

    ~/.agent-context/scripts/Search-Memory.ps1 -Project "my-project" -Pattern "authentication"

This searches canonical project memory plus compaction and branch/fork summaries.

Add -IncludeImports only when you need to inspect the immutable raw migration snapshots as well.

## Structured summary contract

Compaction and branch/fork summaries use:

    ## Goal
    ## Constraints & Preferences
    ## Progress
    ### Done
    ### In Progress
    ### Blocked
    ## Key Decisions
    ## Next Steps
    ## Critical Context

This borrows the useful lifecycle concepts from Pi while keeping Context Spine agent-independent and local-first.

# Context Lifecycle, Migration, Compaction and Branch Summaries

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

## Compaction

Compaction reduces what an agent needs to reload while preserving the originals.

Raw handovers/sessions live beneath:

    memory/projects/<project>/sessions/
    memory/projects/<project>/handovers/

Get-ContextMaintenance.ps1 estimates the uncompacted token load and creates a deterministic plan when the configured threshold is crossed. The default soft thresholds are:

- trigger: 60,000 estimated tokens
- keep recent: 20,000 estimated tokens

The active coding agent performs the summary. No additional model or external API is required. On the work profile this means the already-approved GLM/OpenCode path can do the summarization.

Save-Compaction.ps1 verifies that every planned raw source still exists and has the same SHA-256 hash, validates the structured summary headings, saves the derived summary under context/compactions/<project>/, and records all source hashes in manifest.jsonl.

It does not delete or modify the raw files.

## Branch summaries

Before moving away from an unfinished Git branch, Get-BranchSummaryContext.ps1 records:

- from/to branches
- merge base
- commits unique to the branch being left
- changed files
- recent Context Spine session files

The active coding agent turns that evidence into a structured branch summary and Save-BranchSummary.ps1 stores it under:

    context/branches/<project>/

Again, this is additive: Git history, repository files and raw session memory are untouched.

## Retrieval

Use:

    ~/.agent-context/scripts/Search-Memory.ps1 -Project "my-project" -Pattern "authentication"

This searches canonical project memory plus compaction and branch summaries.

Add -IncludeImports only when you need to inspect the immutable raw migration snapshots as well.

## Structured summary contract

Compaction and branch summaries use:

    ## Goal
    ## Constraints & Preferences
    ## Progress
    ### Done
    ### In Progress
    ### Blocked
    ## Key Decisions
    ## Next Steps
    ## Critical Context

This deliberately borrows the useful lifecycle concepts from Pi while keeping Context Spine agent-independent and local-first.

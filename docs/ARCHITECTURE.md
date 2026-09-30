# Architecture

    Coding Agent
    OpenCode / Codex / other compatible agent
             |
         AGENTS.md
             |
      +------+--------------------+
      |                           |
 Project Skill             Persistent Memory
      |                    raw sessions/handovers
      |                           |
      |                 +---------+----------+
      |                 |                    |
      |          Durable Compaction     Branch/Fork Summaries
      |                 |                    |
      +-----------------+---------+----------+
                                  |
                         Historical Search
                                  |
                           Project Registry
                                  |
                           Local Source Repos

Optional:

    Task/diff -> DecisionEngine -> deterministic routing
                       |
                +------+------+
                |             |
             rules/GLM       Jev
                            optional

## Responsibilities

### Project registry

Records local project identity and path. It is not a copy of the repository.

### Index

Stores metadata and SHA-256 fingerprints. The deterministic index does not duplicate source content into an external service.

### Source search

Search-Context.ps1 searches registered repositories at query time. If rg is installed it is used for speed; otherwise PowerShell Select-String is used.

### Historical-memory search

Search-Memory.ps1 searches durable project/global memory plus derived compaction and branch/fork summaries. Raw migration snapshots are searched only when explicitly requested.

### Project skill

A compact local orientation layer: repository path, detected file types/manifests, canonical instruction/docs pointers and the fingerprint used to generate it. The source repository remains authoritative.

### Memory

Durable user-controlled decisions, lessons and handovers. Raw session/handover history is append-only by policy. Memory is not source code and is not a substitute for current repository truth.

### Migration

Import-ExistingContext.ps1 absorbs prior context without mutating the source location.

It produces:

- an immutable-style raw snapshot under imports/;
- SHA-256-aware merge/copy behavior into canonical memory;
- a migration audit manifest under migrations/.

Conflicting imported project-memory files are preserved under a distinct hash-suffixed filename.

### Active-session compaction

The active coding agent may manage its own context window. Context Spine does not need to replace that agent-specific mechanism.

### Durable compaction

Get-ContextMaintenance.ps1 decides when older persisted session/handover material should be summarized.

Save-Compaction.ps1:

- verifies source files still exist;
- verifies their SHA-256 hashes have not changed since planning;
- validates the structured summary contract;
- stores the derived summary and archived plan;
- records provenance in manifest.jsonl;
- never deletes the raw source files.

The active configured coding agent performs the actual summarization. No extra provider is required.

### Branch/fork summaries

A structured summary preserves an unfinished path when the user leaves a Git branch, forks a coding session, or deliberately explores an alternative approach.

For Git branches, Get-BranchSummaryContext.ps1 adds merge-base, commit and changed-file evidence. Save-BranchSummary.ps1 stores the durable summary without modifying Git history or raw memory.

### Decision engine

An extension point for narrow classification/routing tasks. Jev is one possible adapter. It is never required for core operation.

## Design rules

1. Source repository is canonical for implementation truth.
2. Generated skill is a map, not truth.
3. Raw historical context is preserved.
4. Derived summaries are additive and traceable to their sources.
5. Migration never destroys or silently replaces legacy context.
6. Memory and source evidence stay distinct.
7. No credentials in repository or generated memory files.
8. Work defaults fail closed for external AI.
9. External providers remain replaceable.
10. Prefer deterministic tooling before adding model calls.

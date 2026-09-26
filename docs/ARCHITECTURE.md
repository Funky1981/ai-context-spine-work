# Architecture

```text
                    Coding Agent
                  OpenCode / Codex
                         |
                    AGENTS.md
                         |
               +---------+---------+
               |                   |
        Project Skill         Persistent Memory
               |                   |
               +---------+---------+
                         |
                   Context Search
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
```

## Responsibilities

### Project registry
Records only local project identity and path. It is not a copy of the repository.

### Index
Stores metadata and SHA-256 fingerprints. V1 deliberately does not duplicate source content into an index database.

### Search
Searches registered local repositories at query time. If `rg` is installed it is used for speed; otherwise PowerShell `Select-String` is used.

### Project skill
A compact local orientation layer: repository path, detected file types/manifests, canonical instruction/docs pointers and the fingerprint used to generate it. The source repository remains authoritative.

### Memory
Durable user-controlled decisions, lessons and handovers. Memory is not source code and is not a substitute for current repository truth.

### Context builder
V1 is command-driven: search and project skill information are selected before a coding task. A richer ranked context builder can replace this later without changing the storage boundaries.

### Decision engine
An extension point for narrow classification/routing tasks. Jev is one possible adapter. It is never required for core operation.

## Design rules

1. Source repository is canonical.
2. Generated skill is a map, not truth.
3. Memory and source evidence stay distinct.
4. No credentials in repository or generated files.
5. Work defaults fail closed for external AI.
6. External providers remain replaceable.
7. Prefer deterministic tooling before adding model calls.

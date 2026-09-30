# AI Context Spine

A local-first coding context system for **home and work**.

It provides coding agents with a reusable context layer made from:

- a project registry and lightweight local index
- persistent memory, decisions and handovers
- project skills
- local source and historical-memory search
- safe migration of existing OpenCode memory
- durable context compaction that preserves raw history
- Git-branch and coding-session-fork summaries
- OpenCode integration
- an optional decision-engine adapter boundary
- optional **Jev** support, disabled by default

## Profiles

### Work

The work profile is deliberately restrictive:

- intended model: your approved **GLM** setup through OpenCode
- external AI/API calls: **blocked by default**
- Jev: included but cannot run until explicitly marked approved
- telemetry: none
- package auto-install: none
- credentials stored in repo/config: none
- company-specific content: never belongs in this GitHub repository
- migration, compaction and branch/fork summaries stay local

### Home

The home profile is provider-neutral. Jev support is available as an opt-in adapter, but is disabled until you explicitly enable it and provide JEV_API_KEY as an environment variable.

## Fastest setup

If you cannot clone/download this repository, copy only bootstrap.ps1:

1. Open bootstrap.ps1 in GitHub.
2. Copy its contents into a local bootstrap.ps1.
3. Inspect it.
4. Run:

    # Work
    .\bootstrap.ps1 -Profile work -InstallOpenCode

    # Home
    .\bootstrap.ps1 -Profile home -InstallOpenCode

Default output:

    ~/.agent-context/
    ├── config.json
    ├── AGENTS.md
    ├── memory/
    ├── projects/
    ├── skills/
    ├── index/
    ├── context/
    │   ├── compactions/
    │   ├── branches/
    │   └── pending/
    ├── imports/
    ├── migrations/
    ├── commands/
    └── scripts/

The bootstrap makes **no network calls**.

## Existing context migration

By default the bootstrap checks:

    ~/.config/opencode/

If that legacy OpenCode context exists, it is imported **additively**.

The installer:

- never deletes or edits the original legacy context;
- creates a raw snapshot under ~/.agent-context/imports/;
- records an audit manifest under ~/.agent-context/migrations/;
- immediately verifies the migration against the manifest and SHA-256 hashes;
- merges legacy MEMORY.md, lessons.md and preferences.md into the canonical Context Spine memory with SHA-256 import markers;
- copies legacy memory/projects/** into the new project-memory tree;
- preserves conflicting files under hash-suffixed imported names rather than overwriting either version.

For another legacy context directory:

    .\bootstrap.ps1 -Profile work -InstallOpenCode -ImportContextPath "C:\path\to\old\context"

Use -SkipLegacyImport only when you intentionally do not want the default OpenCode context imported.

## Context lifecycle

OpenCode can manage its own active conversation/context window. Context Spine adds a separate durable layer across sessions and tools.

The durable layer provides:

- append-only raw handovers/session notes;
- deterministic maintenance checks;
- structured compaction summaries derived from older persisted context;
- SHA-256 provenance back to the raw files;
- branch/fork summaries when an unfinished line of work is left;
- historical retrieval through Search-Memory.ps1.

Raw history is not removed by compaction.

See docs/CONTEXT-LIFECYCLE.md for the contract.

## OpenCode

OpenCode V2 uses AGENTS.md for persistent instructions and discovers Markdown commands in .opencode/commands/ or the global OpenCode commands directory. This repo generates compatible guidance and commands without selecting or changing your model.

Existing global AGENTS.md is never overwritten; the bootstrap writes an integration snippet for manual review. Existing OpenCode command files are also preserved.

## Jev

Jev is behind an adapter boundary. It is **not required** for indexing, memory, project skills, search, migration, compaction, OpenCode, or GLM.

Home opt-in:

    $env:JEV_API_KEY = "set-this-in-your-shell-or-secret-store"
    ~/.agent-context/scripts/Enable-Jev.ps1

Work stays GLM-only by default. If policy formally changes later:

    ~/.agent-context/scripts/Enable-Jev.ps1 -ApprovedForWork

That explicit switch changes the local profile; it does not bypass employer policy or configure credentials.

## Register a project

    ~/.agent-context/scripts/Register-Project.ps1 -Name "My App" -Path "C:\Projects\MyApp"

Search source:

    ~/.agent-context/scripts/Search-Context.ps1 -Project "my-app" -Pattern "authentication"

Search historical memory:

    ~/.agent-context/scripts/Search-Memory.ps1 -Project "my-app" -Pattern "authentication"

Check staleness:

    ~/.agent-context/scripts/Test-Staleness.ps1 -Project "my-app"

Check durable context maintenance:

    ~/.agent-context/scripts/Get-ContextMaintenance.ps1 -Project "my-app"

## Repository safety rule

This repository is a **generic bootstrap only**.

Never commit employer source code, internal documentation, logs, database data, credentials, tokens, private project memory, generated work indexes, migration snapshots or generated compaction summaries. Those stay on the machine where they were created.

## V1 philosophy

The core remains intentionally boring: local files, deterministic scripts, explicit project registration, lexical retrieval and additive derived context. It is not a cloud RAG product or an autonomous coding framework.

The lifecycle layer improves long-running work without tying the memory system to one coding agent or one model.

See the docs/ folder for architecture, lifecycle, home/work setup, Jev and security details.

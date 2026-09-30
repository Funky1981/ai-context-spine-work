# Security

## Default posture

AI Context Spine is designed to bootstrap without network access and without credentials.

The bootstrap:

- creates local folders and text files;
- does not download packages;
- does not install binaries;
- does not require administrator rights;
- does not transmit source code or documents;
- does not store API keys;
- does not alter the configured coding model/provider.

## Work profile

The work profile sets:

- external_ai_allowed=false
- jev.enabled=false
- model_provider=glm

Migration, retrieval, maintenance planning and provenance checks are local PowerShell operations.

The Jev adapter checks the work-profile restrictions before making a request. Enabling Jev for a work profile requires the explicit -ApprovedForWork switch and should only be used after employer approval.

## Existing-context migration

The migration path is deliberately non-destructive.

Import-ExistingContext.ps1:

- does not delete, move, rename or rewrite the source context directory;
- copies a raw snapshot into the Context Spine imports directory;
- uses SHA-256 hashes to identify identical content;
- appends global memory rather than replacing it;
- preserves both versions when project-memory filenames conflict;
- records an audit manifest of import actions.

The default bootstrap only auto-discovers the user's legacy ~/.config/opencode/ location. Other context roots must be supplied explicitly with -ImportContextPath.

## Compaction

Context Spine durable compaction is additive.

Before accepting a generated compaction summary, Save-Compaction.ps1 verifies that every planned raw source still exists and still matches its recorded SHA-256 hash.

Successful compaction creates new derived files and manifest entries. It does not delete or rewrite the source handovers/session files.

## Branch/fork summaries

Branch/fork summary tooling only records derived context. It does not rewrite Git history, repository content or coding-session history.

## Existing OpenCode configuration

When -InstallOpenCode is used:

- an existing global AGENTS.md is preserved;
- an integration snippet is generated instead of overwriting it;
- existing OpenCode command files are preserved.

This protects locally customized instructions and commands.

## Secrets

Do not put secrets in:

- this repository;
- config.json;
- memory Markdown files;
- project skills;
- generated index metadata;
- import snapshots intended for wider sharing.

Jev reads JEV_API_KEY from the process environment only.

## Indexed content

The deterministic source index stores file paths, extension, modification time, size and SHA-256 hashes. Search reads local source files on demand. It does not upload them.

## Local generated data

The following may contain private project or employer context and must remain local:

- ~/.agent-context/memory/
- ~/.agent-context/imports/
- ~/.agent-context/migrations/
- ~/.agent-context/context/
- ~/.agent-context/index/
- ~/.agent-context/skills/

Do not push generated local work data back into this public repository.

## Public repository boundary

This repository must remain generic. Never push generated work files back to it.

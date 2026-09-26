# AI Context Spine

A local-first coding context system for **home and work**.

It provides coding agents with a reusable context layer made from:

- a project registry and lightweight local index
- persistent memory and decisions
- project skills
- local context/search helpers
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

### Home

The home profile is provider-neutral. Jev support is available as an opt-in adapter, but is disabled until you explicitly enable it and provide `JEV_API_KEY` as an environment variable.

## Fastest setup

If you cannot clone/download this repository, copy only `bootstrap.ps1`:

1. Open `bootstrap.ps1` in GitHub.
2. Copy its contents into a local `bootstrap.ps1`.
3. Inspect it.
4. Run:

```powershell
# Work
.\bootstrap.ps1 -Profile work

# Home
.\bootstrap.ps1 -Profile home
```

Default output:

```text
~/.agent-context/
├── config.json
├── AGENTS.md
├── memory/
├── projects/
├── skills/
├── index/
├── context/
├── commands/
└── scripts/
```

The bootstrap makes **no network calls**.

To install the generated OpenCode guidance/commands, add `-InstallOpenCode`. Existing global `AGENTS.md` is never overwritten; if one already exists, the bootstrap writes an integration snippet for manual review.

## OpenCode

OpenCode V2 uses `AGENTS.md` for persistent instructions and discovers Markdown commands in `.opencode/commands/` or the global OpenCode commands directory. This repo generates compatible guidance and commands without selecting or changing your model.

## Jev

Jev is behind an adapter boundary. It is **not required** for indexing, memory, project skills, search, OpenCode, or GLM.

Home opt-in:

```powershell
$env:JEV_API_KEY = "set-this-in-your-shell-or-secret-store"
~/.agent-context/scripts/Enable-Jev.ps1
```

Work stays GLM-only by default. If policy formally changes later:

```powershell
~/.agent-context/scripts/Enable-Jev.ps1 -ApprovedForWork
```

That explicit switch changes the local profile; it does not bypass employer policy or configure credentials.

## Register a project

```powershell
~/.agent-context/scripts/Register-Project.ps1 -Name "My App" -Path "C:\Projects\MyApp"
```

This creates a local registry entry, file fingerprint index and starter project skill.

Search it:

```powershell
~/.agent-context/scripts/Search-Context.ps1 -Project "my-app" -Pattern "authentication"
```

Check whether its project skill/index is stale:

```powershell
~/.agent-context/scripts/Test-Staleness.ps1 -Project "my-app"
```

## Repository safety rule

This repository is a **generic bootstrap only**.

Never commit employer source code, internal documentation, logs, database data, credentials, tokens, private project memory, generated work indexes, or company-specific configuration. Those stay on the machine where they were created.

## V1 philosophy

V1 is intentionally boring: local files, deterministic scripts, explicit project registration and lexical retrieval. It is not a cloud RAG product or autonomous coding framework. Better retrieval or additional decision engines can be added later without replacing the memory/skill contracts.

See the `docs/` folder for architecture, home/work setup, Jev and security details.

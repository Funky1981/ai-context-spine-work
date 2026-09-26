# Security

## Default posture

AI Context Spine is designed to bootstrap without network access and without credentials.

The bootstrap:
- creates local folders and text files
- does not download packages
- does not install binaries
- does not require administrator rights
- does not transmit source code or documents
- does not store API keys

## Work profile

The work profile sets:
- `external_ai_allowed=false`
- `jev.enabled=false`
- `model_provider=glm`

The Jev adapter checks these values before making a request. Enabling Jev for a work profile requires the explicit `-ApprovedForWork` switch and should only be used after employer approval.

## Secrets

Do not put secrets in:
- this repository
- `config.json`
- memory Markdown files
- project skills
- generated index metadata

Jev reads `JEV_API_KEY` from the process environment only.

## Indexed content

The deterministic index stores file paths, extension, modification time, size and SHA-256 hashes. Search reads local source files on demand. It does not upload them.

## Public repository boundary

This repository must remain generic. Never push generated work files back to it.

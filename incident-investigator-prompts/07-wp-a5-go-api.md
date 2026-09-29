# Incident Investigator — WP-A5 Go Product API

Prerequisite: A1–A4 phase gate permits UI work. If not, STOP.

Proceed with WP-A5 only.

## Objective
Expose typed, read-oriented backend endpoints for the alerting dashboard without exposing Splunk/SPL.

## Scope
Provide the minimum endpoints required for:
- overview aggregates;
- incident list/filter/sort;
- incident detail;
- incident timeline/fingerprint/event counts;
- alerts;
- internal notification/delivery status where useful;
- approved evidence drill-down from stored cycle artifacts/state.

Use stored product state/artifacts. V1 browser requests must not execute arbitrary SPL or directly query live Splunk. Strict validation, bounded pagination/limits, stable DTOs and consistent errors.

Do not expose secrets, raw internal configuration, model prompts, unrestricted filesystem paths or arbitrary query parameters that become SPL.

No causal/root-cause endpoints. No remediation. No email/Teams. No LIVE.

## Tests
Contract/handler tests, malformed input, pagination/limits, missing incidents, evidence authorization/path safety, deterministic ordering, large-enough fixture response, and frontend-consumable CORS/config only if actually required by local architecture.

## Completion gate
Run tests/build/vet. Report endpoint contract, security boundaries, example response shapes, files changed and exact WP-A6 scope. STOP before dashboard.
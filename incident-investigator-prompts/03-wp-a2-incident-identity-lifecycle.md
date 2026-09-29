# Incident Investigator — WP-A2 Incident Identity & Lifecycle

WP-A1 is approved. Proceed with WP-A2 only.

## Holdout decision
The draft-unreviewed holdout causal GT remains on the separately gated causal-analysis track and is NOT an Alerting V1 dependency. Existing labels may be used only for non-causal facts they validly establish. Do not modify causal GT.

## Scope
Implement only:
- deterministic Incident and IncidentPattern contracts;
- cross-cycle identity and stable occurrence IDs;
- merge/duplicate rules;
- lifecycle state machine;
- trend as a separate property;
- filesystem persistence;
- synthetic/determinism tests.

No Splunk polling, GLM, alerts, notification dispatch, API, React, LIVE, causal changes, or database.

## Critical identity requirement
Distinguish an incident pattern/signature from an incident occurrence. The same failure pattern after a lifecycle/recurrence boundary must be capable of creating a new occurrence linked to the same pattern. Never collapse temporally separate occurrences merely because fingerprints match.

Define deterministic precedence using stable event identity/dedup, RequestGuid overlap where available, fingerprint/template overlap, service/source, temporal adjacency, and lifecycle state. RequestGuid, fingerprint equality, and temporal adjacency must each be insufficient alone. Document tie-breaking.

## Lifecycle
Use NEW → ACTIVE → QUIET → RESOLVED. Define exact deterministic transitions and recurrence semantics. Trend is independent: INCREASING/STABLE/DECREASING. Trend changes never create an occurrence.

Define behaviour when matching events arrive while QUIET and after RESOLVED. Use injected timestamps; no sleeps in tests.

## Persistence
Filesystem persistence is approved for POC. Writes must be atomic/crash-safe. Persist stable occurrence IDs, pattern relationship, state, trend, counts, first/last seen, dedup event identities, evidence refs and recurrence linkage. No database.

## Required scenarios
Test: continuing incident across overlapping polls; duplicate poll events; new events on existing incident; missing RequestGuid; reused/skewed RequestGuid; same fingerprint in separate services; short gap; QUIET receives event; RESOLVED pattern recurs; similar fingerprints but different incidents; restart/reload; byte-identical deterministic state.

Pay particular attention to false merges and false splits.

## Completion gate
Run all tests/build/vet. Report files changed, final contracts, identity/merge precedence, lifecycle rules, recurrence, persistence format, test results, ambiguous cases/limitations, and exact WP-A3 scope. STOP. Do not begin WP-A3.
# Incident Investigator — WP-A3 Incremental Polling, Alerts & Internal Notifications

Prerequisite: WP-A2 must be complete with its tests passing and no unresolved identity/lifecycle defect that would invalidate alert semantics. If not, STOP.

Proceed with WP-A3 only.

## Objective
Create the backend-only running Alerting V1 pipeline: bounded incremental DEV Splunk retrieval → deterministic reduction → incident matching/update → lifecycle/trend update → deterministic alert rules → internal/dashboard notification channel.

## Polling
Reuse the proven DEV Splunk MCP client and safety constraints. Use absolute UTC bounded windows, approved index only, read-only queries, count/guard before fetch where required, slice cap discipline, and deliberate overlap to prevent boundary misses. Deduplicate by stable event identity so overlap never double-counts.

Persist the polling checkpoint/state needed for restart safety. A failed/partial poll must not advance state as if successful. Fail loud on truncation/contract/safety violations.

Do not expose polling cadence as an unbounded tight loop. Make cadence configurable with safe defaults.

## Alert rules
Implement deterministic, configurable rules for at least:
- NEW_INCIDENT;
- EVENTS_INCREASED beyond a documented material threshold;
- SEVERITY_ESCALATED;
- RECURRED_AFTER_RESOLUTION/QUIET according to the approved lifecycle semantics.

Per-incident alert-condition state must prevent every poll from re-firing the same alert. Define re-arm semantics explicitly.

GLM never decides whether an alert fires.

## Notification abstraction
Implement a small pluggable NotificationChannel/Notifier abstraction and dispatcher. V1 implements internal/dashboard delivery only. Delivery outcome is recorded separately from incident/alert state. Delivery failure must never mutate incident identity/lifecycle or create duplicate incidents.

Do not implement email, Teams, Slack, paging, queues or Kafka. Preserve extension points for later approved channels.

## Optional factual GLM summary
If the existing GLM adapter is used, it is optional/config-gated and receives bounded deterministic facts only. Output is untrusted display text, schema validated, and must avoid causal/root-cause language. Incidents must render and alerts must work if GLM is unavailable.

## State/retention
Define bounded retention/compaction for poll snapshots, dedup identities, alerts and delivery outcomes so filesystem state cannot grow indefinitely at POC scale.

## Tests
Use fake transport and deterministic clocks. Cover consecutive polls, overlap, restart, partial failure, silent cap/truncation, dedup, each alert type, alert suppression/re-arm, dispatch failure, GLM disabled/failure, and deterministic replay.

## Completion gate
Run tests/build/vet. Report observed behaviour, files changed, poll/query budgets, state changes, alert rules/re-arm semantics, notification interface, retention, audit evidence and exact WP-A4 scope. STOP. Do not begin WP-A4.
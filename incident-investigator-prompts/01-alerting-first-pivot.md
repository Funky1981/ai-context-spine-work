# Incident Investigator — Alerting-First Pivot

## Purpose

Use this prompt in the existing Incident Investigator repository to pivot the next phase of the POC toward a useful incident alerting and triage application.

The causal-analysis work already completed must be preserved as evidence. Do not delete it, rewrite its historical results, weaken its evaluation gates, or pretend root-cause ranking is solved.

The immediate product goal is now:

> Detect new ERROR/FATAL activity from approved Splunk DEV data, deterministically group related events into incidents, show how many events are linked, and present evidence-backed incident summaries and alerts through a usable dashboard.

Root-cause ranking, remediation recommendations, and autonomous remediation are deferred.

---

## Prompt to give the coding agent

Read the complete repository documentation and current implementation before making changes, especially AGENTS.md, HANDOVER.md, DECISIONS.md, the implementation roadmap, benchmark/evaluation documentation, contracts, security boundaries, Splunk MCP contract, and all WP-06 evaluation artifacts.

Do not implement anything yet.

### Context

The current POC has demonstrated promising incident detection/grouping but weak causal ranking.

Preserve the existing evaluation results as historical evidence. In particular, do not reinterpret strong grouping performance as proof of root-cause accuracy.

We are deliberately changing the next product milestone.

The application should first become an **Incident Alerting & Triage** system.

Its primary questions are:

1. What new ERROR/FATAL activity has appeared?
2. Which events appear to belong to the same incident?
3. How many events/requests are associated with each incident?
4. Which services/sources are affected?
5. When was the incident first and last observed?
6. Is the incident new, ongoing, increasing, decreasing, or apparently quiet/resolved?
7. What representative evidence supports the grouping?
8. Can a human quickly open the incident and understand what happened without reading hundreds of raw Splunk events?

The application must **not** claim a definitive root cause unless a future separately evaluated causal-analysis capability supports that claim.

### Desired pipeline

Splunk DEV MCP
→ bounded ERROR/FATAL retrieval
→ deterministic normalisation
→ fingerprinting/correlation
→ incident lifecycle
→ evidence-backed incident summary
→ dashboard
→ alert/event notification abstraction

The existing deterministic reduction/correlation code should be reused where appropriate rather than replaced with LLM grouping.

### Incident model

Design a concrete incident lifecycle suitable for the POC. At minimum consider:

- incident ID
- status
- first seen UTC
- last seen UTC
- event count
- distinct request/correlation count where available
- affected services/sources
- severity
- representative fingerprints/templates
- representative events/evidence references
- timeline/buckets
- new events since previous observation
- grouping rationale that can be audited

Statuses should be deterministic and explicitly defined. Do not invent sophisticated incident-management workflow unless required by the proof.

### AI boundary

GLM may produce a concise evidence-backed **incident summary** from bounded structured evidence.

Example acceptable wording:

> 418 related error events were observed across three services. Database-connection failures, stored-procedure failures and HTTP 500 responses occurred during the incident window.

Do not allow the model to silently convert temporal ordering or correlation into causation.

Avoid statements such as:

> Root cause: X

unless that capability is separately reintroduced and passes its own evaluation gate.

The deterministic system remains responsible for retrieval, grouping, counts, timestamps, incident identity/lifecycle, evidence references, budgets and security.

### Dashboard requirement

The dashboard is now part of the POC rather than a post-POC feature.

Keep the agreed stack:

- Go backend
- React + TypeScript frontend
- existing Splunk MCP integration
- internal GLM integration only where justified

The initial dashboard should make the reduction in operational noise obvious.

It should support an overview similar in information architecture to:

- active/new incidents
- severity
- concise incident title/summary
- linked event count
- affected service(s)
- first seen
- last seen
- trend/new-event indication

An incident detail view should expose:

- incident metadata
- event/fingerprint counts
- timeline
- representative errors
- affected services
- evidence references
- AI summary if enabled
- raw/source evidence drill-down through an approved backend path

Do not expose arbitrary SPL execution from the browser.

### Alerting

Design alerting as a bounded application capability.

For the first implementation, an alert may simply be an internal application alert/event recorded by the backend and surfaced in the dashboard. Do not introduce email, Teams, Slack, paging, queues, Kafka, or another infrastructure dependency unless an approved requirement already exists.

Define deterministic alert conditions such as:

- newly detected incident
- material increase in linked events
- severity escalation
- recurrence after an explicitly defined quiet/resolved state

Do not ask GLM whether an alert should fire.

### Persistence

Determine the minimum persistence required to distinguish:

- a newly discovered incident
- an already-known incident receiving additional events
- a quiet/resolved incident
- a recurring incident

Do not introduce a database merely because a future production system might need one. First inspect the current architecture and determine whether filesystem persistence is sufficient for the POC. If persistence requirements demonstrate that a database is justified, document that evidence before adding one.

### Evaluation

Create an evaluation plan specifically for the alerting product boundary.

Measure at minimum:

- incident detection recall
- grouping/candidate precision
- duplicate incident rate
- event reduction ratio
- linked-event count correctness
- incident lifecycle correctness
- new-vs-existing classification accuracy
- alert correctness
- evidence support rate
- repeatability
- processing duration

Preserve causal-ranking metrics separately as historical/future causal-analysis metrics. Do not include root-cause accuracy in the alerting V1 GO/NO-GO gate.

### Security

Retain all existing security boundaries.

DEV first.

Splunk access remains read-only.

Use bounded windows and approved indexes.

No arbitrary SPL from the React frontend.

No remediation execution.

No infrastructure changes.

No credentials or secrets in prompts, logs, artifacts, source code, screenshots or fixtures.

All AI output is untrusted and validated.

### Work-package discipline

Do not jump directly into the dashboard.

First inspect what already exists and propose the **smallest sequence of corrective/new work packages** required to pivot from the current WP-06 state to the alerting-first POC.

The sequence should cover, in an order justified by dependencies:

- preservation/freeze of current causal-analysis evidence
- incident lifecycle contract
- state/persistence decision
- incremental Splunk polling/retrieval
- incident update/correlation behaviour
- alert generation
- alerting-specific evaluation
- Go API
- React dashboard
- integrated DEV demonstration

Do not assume those must be ten separate packages; consolidate where that produces cleaner gates.

Each work package must have:

- objective
- scope
- explicit exclusions
- acceptance criteria
- tests/verification
- artifacts/evidence
- stop condition

One work package at a time.

### First response only

For this invocation, do **not** modify code.

Return:

1. your understanding of the pivot;
2. which existing components/results can be reused unchanged;
3. which current roadmap items should be paused or superseded;
4. proposed revised work packages from the current state through the first dashboard demonstration;
5. proposed V1 GO/NO-GO metrics;
6. any architectural or security concerns;
7. the exact first work package you recommend implementing;
8. any documentation that must be corrected before implementation.

Stop and wait for approval.

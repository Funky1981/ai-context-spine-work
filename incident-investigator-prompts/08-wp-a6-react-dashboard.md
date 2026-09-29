# Incident Investigator — WP-A6 React Alerting Dashboard

Prerequisite: WP-A5 API accepted. Proceed with WP-A6 only.

## Objective
Create a usable engineer-facing dashboard that makes Splunk noise reduction and incident status immediately understandable.

## Overview
Show at minimum:
- active/new/quiet/recently resolved incidents;
- severity;
- concise factual title/summary;
- linked event count;
- distinct request count where available;
- affected services/sources;
- first/last seen;
- trend;
- recurrence/pattern information where useful;
- current alerts/notification state.

Provide sensible loading, empty, stale-data and error states.

## Incident detail
Show:
- occurrence ID and related pattern/signature;
- lifecycle + trend;
- first/last seen;
- linked-event/fingerprint/request counts;
- affected services;
- timeline;
- representative errors/templates;
- evidence references/drill-down;
- recurrence history where available;
- optional factual AI summary clearly presented as a summary, not root cause.

Do not present correlation or temporal order as causation. Do not display “root cause”, “probable cause”, remediation or causal-chain UI in V1.

No arbitrary SPL input. No LIVE push requirement. Polling/refresh can be bounded and simple.

## UX goal
An engineer should be able to identify the small set of incidents behind a large event volume and open one to understand the factual evidence without reading hundreds of raw events.

## Verification
Frontend tests for key states/components plus a manual walkthrough using representative stored/demo data. Keep UI practical; do not spend the WP on visual polish.

## Completion gate
Report screenshots/walkthrough evidence, tests/build results, files changed, known UX limitations and exact WP-A7 scope. STOP.
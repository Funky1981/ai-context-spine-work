# Incident Investigator — WP-A7 Integrated DEV Demonstration

Prerequisite: WP-A6 accepted. Proceed with WP-A7 only.

## Objective
Prove the complete Alerting V1 workflow in DEV, repeatably.

Run the real approved DEV path:
bounded Splunk poll → dedup/reduction → incident identity/lifecycle → alert generation → internal notification → persisted state → Go API → React dashboard → incident/evidence drill-down.

## Demonstration evidence
Capture:
- starting state and poll window;
- raw ERROR/FATAL count;
- number of incidents produced/updated;
- linked counts;
- alert decisions and suppression;
- lifecycle/trend updates;
- dashboard overview;
- one or more incident details;
- evidence drill-down;
- restart/reload behaviour;
- timings;
- audit trail.

Demonstrate that repeated polling does not duplicate events/incidents/alerts and that an engineer can understand the incident set without inspecting hundreds of raw events.

No LIVE. No external notification delivery. No causal/root-cause claims. No remediation.

## Final V1 gate
Re-run the frozen deterministic evaluation as appropriate and compare demo behaviour with the gate. Report PROCEED / CONDITIONAL / STOP for Alerting V1.

## Completion gate
Produce a concise integrated demo report, exact commands/runbook, test/build results, limitations, and backlog. STOP for PROJECT/PHASE REVIEW. Do not start causal improvements, external notifications or LIVE work automatically.
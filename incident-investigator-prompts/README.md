# Incident Investigator Prompts

This folder contains the complete prompt sequence for the **Alerting V1** pivot so the work can progress without requesting a new prompt after every work package.

## Product direction

**Splunk ERROR/FATAL events → deterministic grouping → stable incident occurrences → lifecycle/trend → alerts → internal notifications → Go API → React dashboard.**

The existing causal/root-cause work is preserved as a separately gated future capability. Alerting V1 must not claim unsupported root cause.

## Execution order

1. `01-alerting-first-pivot.md` — completed review/pivot prompt.
2. `02-wp-a1-approval-and-corrections.md` — WP-A1 documentation/evidence freeze.
3. `03-wp-a2-incident-identity-lifecycle.md` — deterministic cross-poll incident identity, lifecycle and persistence.
4. `04-wp-a3-polling-alerts-notifications.md` — incremental DEV polling, alert rules and internal notification abstraction.
5. `05-wp-a4-alerting-evaluation-gate.md` — reproducible Alerting V1 evaluation.
6. `06-phase-review-a1-a4.md` — **review checkpoint**. Do not implement from this prompt.
7. `07-wp-a5-go-api.md` — typed dashboard API, only if phase review permits.
8. `08-wp-a6-react-dashboard.md` — engineer-facing alerting dashboard.
9. `09-wp-a7-integrated-dev-demo.md` — complete DEV demonstration and V1 gate.
10. `10-phase-review-alerting-v1.md` — **final review checkpoint**. Do not implement from this prompt.
11. `11-post-v1-roadmap-guardrails.md` — reference only; future email/Teams, causal analysis, remediation and LIVE boundaries.

## How to use this pack

Run one work-package prompt at a time. The coding agent must obey each prompt's prerequisite and STOP condition.

You do **not** need to return for review after every work package.

Recommended human/technical-lead review points:

- **After WP-A4:** run `06-phase-review-a1-a4.md` and send the complete review/results for independent review before continuing to API/UI.
- **After WP-A7:** run `10-phase-review-alerting-v1.md` and send the complete final review/results for independent review.

If a work package fails its acceptance criteria, exposes a security issue, requires changing a frozen metric/ground truth, proposes LIVE access, or requires a major architecture change, stop rather than blindly moving to the next prompt.

## Important boundaries

- DEV only; Splunk read-only.
- No arbitrary SPL from browser.
- No root-cause claims in Alerting V1.
- No remediation execution.
- Internal/dashboard notifications only in V1.
- Email/Teams are post-V1 approved-channel work.
- Filesystem persistence for POC unless measured requirements justify change.
- GLM never decides detection, grouping, lifecycle, alert firing, recipients or permitted delivery channels.
- Preserve WP-06 causal artifacts unchanged.
- Do not expose credentials, secrets, internal hostnames or proprietary data in this public repository.

## Public-repository warning

This GitHub repository is public. Keep prompts generic. Do not commit company-sensitive screenshots, real event payloads, credentials, tokens, internal URLs, proprietary SPL, internal service names, or confidential artifacts here.

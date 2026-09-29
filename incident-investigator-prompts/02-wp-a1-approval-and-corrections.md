# Incident Investigator — WP-A1 Approval and Corrections

## Instruction

The alerting-first pivot review is approved with two corrections.

Proceed with **WP-A1 only**.

Before implementation, incorporate these decisions into the pivot documentation.

## 1. V1 evaluation thresholds

Do not freeze arbitrary thresholds for capabilities that have not yet been baselined.

Existing metrics with historical evidence may retain justified provisional thresholds, including:

- incident detection recall
- grouping/candidate precision
- evidence support

For genuinely new alerting/lifecycle metrics, including:

- duplicate incident rate across cycles
- lifecycle correctness
- new-vs-existing classification accuracy
- alert correctness
- linked-event count correctness
- processing duration

record the metric definitions now, but treat thresholds as **PROVISIONAL** until WP-A4 measures actual baseline behaviour.

WP-A4 must present measured baseline values and recommend justified GO/NO-GO thresholds for review before those thresholds are frozen.

Do not weaken a metric after observing poor results merely to obtain a pass. Any threshold recommendation must include its operational rationale.

## 2. Separate lifecycle state from trend

Do not model `INCREASING` and `DECREASING` as incident lifecycle states.

Use a simpler deterministic lifecycle along the lines of:

```text
NEW
→ ACTIVE
→ QUIET
→ RESOLVED
```

with recurrence represented explicitly when a resolved/quiet incident returns according to the eventual identity/recurrence contract.

Model event-rate direction separately as a trend property, for example:

```text
INCREASING
STABLE
DECREASING
```

The exact lifecycle and recurrence semantics are to be designed and reviewed in WP-A2. Do not prematurely encode them in WP-A1.

WP-A2 remains a mandatory review gate before WP-A3 because cross-poll incident identity is the highest-risk design decision.

## Execute WP-A1 only

Now execute WP-A1 only:

- record the alerting-first pivot;
- freeze/preserve all WP-06 causal-analysis artifacts unchanged;
- explicitly park WP-06R;
- update stale HANDOVER and DECISIONS documentation;
- rewrite the roadmap to the approved A-series;
- update POC scope, architecture, contracts, dashboard specification, evaluation documentation, protocol and README as required;
- clearly separate Alerting V1 from the future causal-analysis capability;
- record filesystem persistence as the POC decision, with database reconsideration only if scale/concurrency evidence later requires it;
- document the pluggable notification-channel architecture, with internal/dashboard notification as the only V1 implementation and email/Teams as future approved channels;
- preserve DEV-only, read-only Splunk boundaries;
- make no Go or React product-code changes.

Do **not** merge WP-A1 into WP-A2.

## Completion report and stop condition

After WP-A1:

1. report every file changed;
2. summarise the resulting canonical product scope;
3. identify any unresolved contradictions between documents;
4. show the exact proposed WP-A2 scope;
5. **STOP for review before implementing WP-A2.**

Do not begin WP-A2, WP-A3, API, dashboard, external notifications, LIVE access, causal-analysis corrections, or remediation work without further approval.

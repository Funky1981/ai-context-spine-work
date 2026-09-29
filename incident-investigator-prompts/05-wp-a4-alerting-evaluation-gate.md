# Incident Investigator — WP-A4 Alerting Evaluation

Prerequisite: WP-A3 backend pipeline complete and stable. Proceed with WP-A4 only.

## Objective
Build and run a reproducible Alerting V1 evaluation before any dashboard work.

## Evaluation design
Reuse existing corpus/GT only where labels validly support detection/grouping facts. Do not tune against or reinterpret unreviewed causal GT. Extend evaluation with deterministic observation-sequence fixtures that model successive poll cycles and known expected lifecycle/alert outcomes. Add noise-rich data/fixtures where required to measure operational reduction honestly.

Score at minimum:
- incident detection recall;
- grouping/candidate precision;
- duplicate incident rate across cycles;
- event reduction/noise-exclusion using an explicitly defined operational formula;
- linked-event count correctness;
- lifecycle transition correctness;
- new-vs-existing classification;
- alert precision and alert recall;
- evidence support;
- deterministic repeatability;
- processing duration per cycle;
- false merge rate and false split rate.

Root-cause/top-cause and symptom-vs-cause metrics are historical/future causal-track metrics only and cannot fail Alerting V1.

## Threshold discipline
Historical metrics may retain previously justified provisional thresholds. New metrics must first be measured. Recommend final GO/NO-GO thresholds only after baseline measurement, with operational rationale. Never lower a target merely to turn a failure into a pass.

Separate model-summary text quality from deterministic product gate metrics.

## Method
Freeze evaluation definitions/fixtures before final gate run. Preserve raw artifacts and aggregate/per-case/per-sequence results. Ensure repeatability from a clean state and restart scenarios.

## Decision
Return PROCEED_TO_API_UI, CONDITIONAL, or STOP/PIVOT with evidence. CONDITIONAL must list exact deficiencies and bounded corrective work.

## Completion gate
Report metric definitions, baseline values, proposed justified thresholds, final frozen run results, failures, known limitations and decision. STOP for a PHASE REVIEW. Do not begin WP-A5 unless the deterministic Alerting V1 gate supports proceeding.
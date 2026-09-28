# Incident Investigator — WP-06A Causal Ranking & Repeatability Review Prompt

**Purpose:** corrective evaluation package before the existing product/API/dashboard gate.

**Status:** review first. Do not implement until the proposed corrective package has been reviewed.

## Prompt

> **CONTINUE IN THIS CHAT**
>
> Continue the Incident Investigator POC from the current repository state and current handover.
>
> Do not start the React dashboard, product API, LIVE integration, Fix Advisor, Judge agent, or any later product work.
>
> The latest evaluation is promising enough to continue, but it has identified two weaknesses that must be addressed before proceeding:
>
> 1. root-cause ranking accuracy;
> 2. run-to-run repeatability.
>
> Treat this as a corrective evaluation package before the existing product/UI gate.
>
> First, read and inspect the current repository state, including at minimum:
>
> - `HANDOVER.md`
> - `DECISIONS.md`
> - `AGENTS.md`
> - `IMPLEMENTATION-ROADMAP.md`
> - `BENCHMARK-AND-EVALUATION.md`
> - `INVESTIGATION-PROTOCOL.md`
> - `CONTRACTS.md`
> - current WP-06 evaluation artifacts
> - development and holdout corpus/ground-truth definitions
> - relevant reduction, investigation, GLM and evaluation implementation
>
> Do not make changes immediately.
>
> ## PHASE 1 — REVIEW
>
> Report:
>
> 1. current branch/HEAD or, if this repository intentionally remains non-git, confirm that state;
> 2. working tree/repository state;
> 3. exact current evaluation metrics;
> 4. evidence for the root-cause ranking weakness;
> 5. evidence for the repeatability weakness;
> 6. whether the proposed deterministic abstention normalisation is justified;
> 7. whether the proposed reduction-gate recalibration is methodologically valid;
> 8. status of the holdout ground-truth engineer review;
> 9. your proposed smallest corrective work package.
>
> The objective is **NOT** to make the benchmark numbers look better.
>
> The objective is to determine whether the system can more reliably identify the upstream causal failure rather than a salient downstream symptom.
>
> ## CAUSAL REASONING REQUIREMENT
>
> Investigations should explicitly distinguish:
>
> - observed event;
> - candidate cause;
> - upstream cause;
> - downstream symptom;
> - supporting evidence;
> - contradicting evidence;
> - temporal relationship;
> - dependency relationship;
> - explanatory coverage;
> - uncertainty / insufficient evidence.
>
> Do **NOT** implement a rule that simply assumes the earliest event is the root cause.
>
> A candidate root cause should be preferred only when evidence indicates that it plausibly explains downstream observations.
>
> Where evidence cannot distinguish causes, the system must abstain or report uncertainty rather than invent certainty.
>
> ## REPEATABILITY
>
> Investigate why identical cases produce different root-cause selections or abstain/report decisions across repeated runs.
>
> Do not hide model instability with arbitrary deterministic overrides.
>
> Deterministic normalisation is permitted only where it enforces an already-defined semantic contract and does not manufacture a causal conclusion.
>
> ## GROUND TRUTH
>
> Do not tune against unreviewed holdout answers.
>
> If holdout ground truth remains draft/unreviewed:
>
> - preserve it;
> - do not expose it to runtime GLM;
> - do not optimise prompts or logic against individual holdout cases;
> - clearly distinguish provisional holdout measurements from engineer-confirmed measurements.
>
> ## EVALUATION
>
> Preserve the existing benchmark and frozen evidence wherever possible.
>
> Any changes must be general causal-reasoning improvements, not incident-specific rules or prompt hints.
>
> After implementation, rerun the appropriate development evaluation first.
>
> Only run holdout evaluation under the existing benchmark rules and only if doing so does not contaminate the holdout.
>
> Compare before vs after for at least:
>
> - incident recall;
> - candidate precision;
> - evidence-support rate;
> - reduction ratio;
> - top-cause accuracy;
> - repeatability/agreement;
> - abstention behaviour;
> - query/model budgets;
> - investigation duration.
>
> Explicitly report any regression.
>
> ## SUCCESS CRITERION
>
> The corrective package succeeds only if root-cause ranking and/or repeatability materially improve without unacceptable degradation to incident detection, candidate precision, evidence grounding, bounded execution or benchmark integrity.
>
> A failed experiment is an acceptable result.
>
> Do not weaken gates to obtain a pass.
>
> Do not proceed automatically to API/dashboard work.
>
> At completion:
>
> 1. run all relevant tests and validation;
> 2. preserve raw evaluation artifacts;
> 3. update `DECISIONS.md` and `HANDOVER.md`;
> 4. document exactly what changed and why;
> 5. report before/after metrics;
> 6. give a **PROCEED / CONDITIONAL / STOP** recommendation for moving to the existing product/API/dashboard stage;
> 7. **STOP and wait for review.**
>
> Start with **PHASE 1 review only**. Do not implement until you have reported your proposed corrective package.

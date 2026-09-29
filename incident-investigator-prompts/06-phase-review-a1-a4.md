# Incident Investigator — Phase Review Gate: A1–A4

Use this after WP-A4. Do not implement code in response.

Review WP-A1 through WP-A4 as one phase. Verify canonical docs, preserved WP-06 causal baseline, incident identity/pattern model, lifecycle/trend, persistence, polling safety, alert semantics, notification abstraction, retention, evaluation fixtures and final metrics from artifacts rather than memory.

Look specifically for false merges, false splits, duplicate counting across overlapping polls, unstable recurrence, alert storms, state corruption/restart problems, silent Splunk truncation, causal-language leakage, arbitrary threshold weakening and any mismatch between docs/tests/code.

Return:
1. exact completed scope;
2. exact metric table;
3. PASS/FAIL per frozen gate;
4. architectural/security findings;
5. defects that must block UI;
6. non-blocking debt;
7. GO / CONDITIONAL / STOP for WP-A5/A6;
8. any bounded corrective package required.

STOP. No implementation.
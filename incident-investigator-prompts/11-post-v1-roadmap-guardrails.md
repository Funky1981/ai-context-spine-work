# Incident Investigator — Post-V1 Guardrails

This is not an execution prompt. It records what may happen only after Alerting V1 final review.

## External notifications
Email/Teams may be implemented only after the organisation-approved transport/auth/recipient policy is known. Add each as a NotificationChannel without changing detection/identity/alert logic. Test retries, idempotency, recipient/config safety, redaction and delivery audit. Never place credentials in repo/config examples.

## Causal analysis
Resume as a separately gated capability using preserved WP-06 evidence and a corrective package. Do not silently reintroduce “root cause” into Alerting V1. Improve causal ranking scientifically, preserve frozen benchmarks/holdouts, distinguish facts from hypotheses, and require evidence/falsification.

## Remediation
Recommendations are later than validated causal analysis. Automatic production remediation remains prohibited unless separately designed, risk-assessed and explicitly approved.

## LIVE
LIVE remains separate, read-only and approval-gated. DEV success does not authorize LIVE access.

## Platform engineering
Do not add a database, queue, Kafka, vector store, multi-agent framework or other infrastructure without measured requirements. Revisit filesystem persistence if concurrency, retention, queryability or scale demonstrates the need.

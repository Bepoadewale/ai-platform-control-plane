# Observability and SLOs

The API exposes Prometheus metrics at `/metrics`: request totals, request duration, and policy
denials. The local Compose smoke test has exercised a Prometheus scrape/query and verified the
provisioned Grafana dashboard. Provisioning duration/failure, active-environment,
environment-age, pending-approval, and destroy-failure metrics remain metric-contract/production
hardening work; they are not presented as locally emitted series.

When `OTEL_EXPORTER_OTLP_ENDPOINT` is configured, FastAPI HTTP instrumentation exports traces to
the local OpenTelemetry Collector. `make compose-smoke` has verified collector receipt of a
`GET /api/v1/catalog` span. Explicit child spans for policy evaluation, planning, approval,
desired-state publication, and reconciliation are a production observability enhancement, not
executed local evidence.

Suggested SLOs: 99.9% successful authenticated read requests over 30 days; 99% of accepted
development requests reach a terminal state within 10 minutes; 100% of state transitions emit an
audit event. These are illustrative objectives, not measured production SLOs.

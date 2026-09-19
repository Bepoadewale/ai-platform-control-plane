# Observability and SLOs

The API exposes Prometheus metrics at `/metrics`: request totals/duration and policy denials today; the dashboard and metric contract reserve provisioning duration/failure, active-environment, environment-age, pending-approval, and destroy-failure metrics for the persistent reconciler.

Suggested SLOs: 99.9% successful authenticated read requests over 30 days; 99% of accepted development requests reach a terminal state within 10 minutes; 100% of state transitions emit an audit event. Trace API request, policy decision, plan, Git commit, and reconciliation under a shared request id using OpenTelemetry in the production deployment.

# Observability

The cloud pilot included dashboards, metrics, and request traces alongside the platform.
Prometheus collected health and request data from both API replicas; Tempo showed request traces;
and Grafana displayed the collected information.

The pilot also generated a real alert: a controlled invalid-token burst fired
`PilotUnauthorizedRequestBurst`. A bounded authenticated request sample returned a two-minute
availability estimate of `1`.

This proves the tools were connected and useful during the pilot; it is not a long-term reliability
claim. Longer traffic tests, alert routing, error budgets, and service-level objectives remain in
[Production Evolution](production-evolution.md).

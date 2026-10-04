# Observability

The reference cloud stack ran Prometheus, Tempo, Grafana, and an OpenTelemetry Collector alongside
the control plane. Prometheus discovered both API replicas; Tempo returned control-plane HTTP
traces; Grafana exposed the provisioned dashboard.

The pilot also generated a real alert: a controlled invalid-token burst fired
`PilotUnauthorizedRequestBurst`. A bounded authenticated request sample returned a two-minute
availability estimate of `1`.

This is operational evidence, not an SLO certification. The next production work is to define
longer SLO windows, route alerts to an owned receiver, calculate policy-backed error budgets, emit
full lifecycle child spans, and measure sustained traffic. See [Production Evolution](production-evolution.md).

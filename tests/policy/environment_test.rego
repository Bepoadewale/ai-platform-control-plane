package platform.environment

test_agent_production_denied if {
  "agents cannot autonomously request production" in deny with input as {"actor": {"tenant_id": "team-demo", "is_agent": true}, "request": {"team": "team-demo", "environment_type": "production", "workload": {"privileged": false}, "observability": true, "ttl_hours": 0}}
}

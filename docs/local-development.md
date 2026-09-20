# Local development

`make install && make test && make demo` runs the rendered-state workflow without Docker, Kubernetes, AWS, or credentials. `make run` starts the API.

For the full executed local control loop, start Docker Desktop and install kind, kubectl, and Helm, then run `make demo-local`. It uses temporary local signing material and never needs cloud credentials. It starts and stops OPA automatically, retains the `ai-platform-local` cluster for subsequent runs, and removes the demo workload before exiting.

`make bootstrap-local` remains a manual chart bootstrap. `make compose-smoke` brings up and validates local Keycloak, OPA, PostgreSQL, OTel Collector, Prometheus, Grafana, and the control plane. `ARGOCD_TARGET_REVISION=$(git branch --show-current) make argocd-demo` applies the current branch to local Argo CD; it verifies sync plus deployment readiness, while aggregate Application health is currently an open observation issue.

For Codex MCP, point a project MCP configuration at `mcp-server` after installing its optional SDK dependency. Example prompt: “Use the platform MCP tools to create a temporary dev environment for demo-api with PostgreSQL and Redis.”

# Local development

`make install && make test && make demo` runs the rendered-state workflow without Docker, Kubernetes, AWS, or credentials. `make run` starts the API.

For the full executed local control loop, start Docker Desktop and install kind, kubectl, and Helm, then run `make demo-local`. It uses temporary local signing material and never needs cloud credentials. It starts and stops OPA automatically, retains the `ai-platform-local` cluster for subsequent runs, and removes the demo workload before exiting.

For a clean local infrastructure bootstrap, run `make bootstrap-local`. It creates the `ai-platform-local` kind cluster, installs Metrics Server and Argo CD, and configures Argo CD 3.x to persist resource health for the demo. `make compose-smoke` brings up and validates local Keycloak, OPA, PostgreSQL, OTel Collector, Prometheus, Grafana, and the control plane. `make argocd-demo` applies the current branch to local Argo CD and waits for `Synced/Healthy` plus deployment readiness.

To reset only Project 1 local state, run `make clean-local`. It removes this repository's Compose containers, named volumes, locally built Compose image, and `ai-platform-local` kind cluster. It does not remove unrelated Docker images or containers.

For Codex MCP, point a project MCP configuration at `mcp-server` after installing its optional SDK dependency. Example prompt: “Use the platform MCP tools to create a temporary dev environment for demo-api with PostgreSQL and Redis.”

# Local development

`make install && make test && make demo` runs the core workflow without Docker, Kubernetes, AWS, or credentials. `make run` starts the API.

For a cluster demo, create a kind cluster, install Argo CD and Prometheus using their official, version-pinned release instructions, then `helm upgrade --install golden-path platform/helm/golden-path -f environments/team-demo/demo-api/values.yaml`. This repository intentionally avoids a bootstrap script that downloads or mutates a cluster unattended. The Helm chart is the local data-plane artifact; reconciliation status remains a real integration milestone.

For Codex MCP, point a project MCP configuration at `mcp-server` after installing its optional SDK dependency. Example prompt: “Use the platform MCP tools to create a temporary dev environment for demo-api with PostgreSQL and Redis.”

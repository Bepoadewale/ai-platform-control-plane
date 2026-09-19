# Local development

`make install && make test && make demo` runs the core workflow without Docker, Kubernetes, AWS, or credentials. `make run` starts the API.

For a cluster demo, install kind/kubectl/Helm then run `make bootstrap-local`; it creates `ai-platform-local` only if absent and applies the golden path. Install Argo CD and Prometheus using their official, version-pinned release instructions, then point the included Application manifest at your fork. The Helm chart is the local data-plane artifact. Use `docker compose up --build` for the API plus local PostgreSQL boundary.

For Codex MCP, point a project MCP configuration at `mcp-server` after installing its optional SDK dependency. Example prompt: “Use the platform MCP tools to create a temporary dev environment for demo-api with PostgreSQL and Redis.”

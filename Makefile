.PHONY: install test lint run demo demo-local bootstrap-local clean-local terraform-validate helm-lint compose-up compose-smoke console-local console-smoke argocd-demo public-demo pilot-guardrails-bootstrap pilot-guardrails-apply pilot-cloud-bootstrap-github-oidc pilot-cloud-destroy pilot-cloud-push-image pilot-cloud-put-gitops-secret pilot-cloud-bootstrap-runtime pilot-cloud-smoke pilot-cloud-ha-check pilot-cloud-load-slo pilot-cloud-slo-alert-check pilot-cloud-rollback-check pilot-cloud-cost-evidence pilot-cloud-validate pilot-cloud-gitops-lifecycle pilot-cloud-console pilot-cloud-console-validate pilot-cloud-public-demo pilot-cloud-console-public-demo

PYTHON := $(if $(wildcard .venv/bin/python),.venv/bin/python,python3)

install:
	$(PYTHON) -m pip install -e '.[dev]'

test:
	$(PYTHON) -m pytest -q

lint:
	$(PYTHON) -m ruff check control-plane/src control-plane/tests cli/src

run:
	PYTHONPATH=control-plane/src $(PYTHON) -m uvicorn platform_control_plane.api.main:app --reload

demo:
	PYTHONPATH=control-plane/src $(PYTHON) examples/demo.py

demo-local:
	PYTHONPATH=control-plane/src $(PYTHON) scripts/demo-local.py

bootstrap-local:
	./scripts/bootstrap-local.sh

clean-local:
	./scripts/clean-local.sh

terraform-validate:
	terraform -chdir=infrastructure/terraform/environments/aws init -backend=false
	terraform -chdir=infrastructure/terraform/environments/aws validate

helm-lint:
	helm lint platform/helm/golden-path

compose-up:
	docker compose up -d --build

compose-smoke:
	./scripts/compose-smoke.sh

console-local:
	docker compose up -d --build control-plane keycloak opa postgres otel-collector prometheus grafana operator-console
	@echo "Operator Console: http://localhost:4173"

console-smoke:
	./scripts/console-browser-smoke.sh

argocd-demo:
	./scripts/argocd-demo.sh

public-demo:
	./scripts/start-public-demo.sh

pilot-guardrails-bootstrap:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/bootstrap-pilot-guardrails.sh

pilot-guardrails-apply:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} APPLY_GUARDRAILS=$${EXPECTED_AWS_ACCOUNT_ID:-654654474502} ./scripts/bootstrap-pilot-guardrails.sh

pilot-cloud-plan:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-plan.sh

pilot-cloud-apply:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} APPLY_CLOUD_PILOT=$${EXPECTED_AWS_ACCOUNT_ID:-654654474502} ./scripts/pilot-cloud-apply.sh

pilot-cloud-bootstrap-github-oidc:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} BOOTSTRAP_GITHUB_OIDC=$${EXPECTED_AWS_ACCOUNT_ID:-654654474502} ./scripts/pilot-cloud-bootstrap-github-oidc.sh

pilot-cloud-destroy:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} DESTROY_CLOUD_PILOT=$${EXPECTED_AWS_ACCOUNT_ID:-654654474502} ./scripts/pilot-cloud-destroy.sh

pilot-cloud-push-image:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-push-image.sh

pilot-cloud-put-gitops-secret:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-put-gitops-secret.sh

pilot-cloud-bootstrap-runtime:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-bootstrap-runtime.sh

pilot-cloud-gitops-lifecycle:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-gitops-lifecycle.sh

pilot-cloud-smoke:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-smoke.sh

pilot-cloud-ha-check:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-ha-check.sh

pilot-cloud-load-slo:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-load-slo.sh

pilot-cloud-slo-alert-check:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-slo-alert-check.sh

pilot-cloud-rollback-check:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-rollback-check.sh

pilot-cloud-cost-evidence:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-cost-evidence.sh

pilot-cloud-validate:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-validate.sh

pilot-cloud-console:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-console.sh

pilot-cloud-console-validate:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-console-validate.sh

pilot-cloud-public-demo:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-public-demo.sh

pilot-cloud-console-public-demo:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-console-public-demo.sh

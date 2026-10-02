.PHONY: install test lint run demo demo-local bootstrap-local clean-local terraform-validate helm-lint compose-up compose-smoke argocd-demo public-demo pilot-guardrails-bootstrap pilot-guardrails-apply pilot-cloud-plan pilot-cloud-apply pilot-cloud-destroy pilot-cloud-push-image pilot-cloud-bootstrap-runtime pilot-cloud-smoke pilot-cloud-public-demo

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

pilot-cloud-destroy:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} DESTROY_CLOUD_PILOT=$${EXPECTED_AWS_ACCOUNT_ID:-654654474502} ./scripts/pilot-cloud-destroy.sh

pilot-cloud-push-image:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-push-image.sh

pilot-cloud-bootstrap-runtime:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-bootstrap-runtime.sh

pilot-cloud-smoke:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-smoke.sh

pilot-cloud-public-demo:
	AWS_PROFILE=$${AWS_PROFILE:-ai-platform-pilot-key} ./scripts/pilot-cloud-public-demo.sh

.PHONY: install test lint run demo demo-local bootstrap-local terraform-validate helm-lint compose-up compose-smoke argocd-demo

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

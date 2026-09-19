.PHONY: install test lint run demo terraform-validate helm-lint

install:
	python3 -m pip install -e '.[dev]'

test:
	python3 -m pytest -q

lint:
	python3 -m ruff check control-plane/src control-plane/tests cli/src

run:
	PYTHONPATH=control-plane/src uvicorn platform_control_plane.api.main:app --reload

demo:
	PYTHONPATH=control-plane/src python3 examples/demo.py

terraform-validate:
	terraform -chdir=infrastructure/terraform/environments/aws init -backend=false
	terraform -chdir=infrastructure/terraform/environments/aws validate

helm-lint:
	helm lint platform/helm/golden-path

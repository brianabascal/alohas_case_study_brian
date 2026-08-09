# Atajos. dbt se lanza desde transform/ (sin --project-dir / --profiles-dir).
PYTHON ?= .venv/bin/python
DBT ?= .venv/bin/dbt

.PHONY: venv extract debug run test build

venv:
	pyenv exec python -m venv .venv
	.venv/bin/pip install -r requirements.txt
	./scripts/patch_venv_activate.sh

extract:
	$(PYTHON) scripts/extract.py

debug:
	cd transform && $(DBT) debug

run:
	cd transform && $(DBT) run

test:
	cd transform && $(DBT) test

build: run test

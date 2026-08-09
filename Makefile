# Atajos. dbt se lanza desde transform/ (sin --project-dir / --profiles-dir).
# Rutas absolutas: las recetas de dbt hacen cd a transform/ antes de ejecutar.
PYTHON ?= $(CURDIR)/.venv/bin/python
DBT ?= $(CURDIR)/.venv/bin/dbt

.PHONY: venv extract debug run test build report

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

# Deja el report en report/index.html, listo para abrir en el navegador.
report:
	$(PYTHON) report/build_report.py

## Day 19 — Vector Store + Feature Store lab.
## Two paths: lightweight (default, no Docker) and full Docker.

ifeq ($(OS),Windows_NT)
    VENV     := .venv
    PY       := $(VENV)/Scripts/python.exe
    PIP      := $(VENV)/Scripts/pip.exe
    JUPYTER  := $(VENV)/Scripts/jupyter.exe
    JUPYTEXT := $(VENV)/Scripts/jupytext.exe
    UVICORN  := $(VENV)/Scripts/uvicorn.exe
    PYTEST   := $(VENV)/Scripts/pytest.exe
    SETUP_LITE := setup-lite.bat
    SETUP_DOCKER := setup-docker.bat
else
    VENV     := .venv
    PY       := $(VENV)/bin/python
    PIP      := $(VENV)/bin/pip
    JUPYTER  := $(VENV)/bin/jupyter
    JUPYTEXT := $(VENV)/bin/jupytext
    UVICORN  := $(VENV)/bin/uvicorn
    PYTEST   := $(VENV)/bin/pytest
    SETUP_LITE := bash setup-lite.sh
    SETUP_DOCKER := bash setup-docker.sh
endif

.DEFAULT_GOAL := help

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nLightweight path (default):\n"} \
	      /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ─────────────────────────────────────────────────────────────
# Lightweight path (default) — no Docker, in-process Qdrant
# ─────────────────────────────────────────────────────────────

setup-lite: ## [lite] Create venv + install + seed corpus + smoke test
	@$(SETUP_LITE)

verify-lite: ## [lite] 5-second smoke test (Qdrant memory + BM25 + Feast SQLite)
	@$(PY) scripts/verify_lite.py

seed: ## [both] (Re)generate data/corpus_vn.jsonl + data/golden_set.jsonl
	@$(PY) scripts/seed_corpus.py

api: ## [lite] Start FastAPI /search on http://localhost:8000
	@$(UVICORN) app.main:app --reload --port 8000

lab: ## [lite] Open Jupyter Lab on http://localhost:8888
	-@$(JUPYTEXT) --to notebook --update notebooks/*.py
	@$(JUPYTER) lab --notebook-dir=notebooks --ServerApp.token='' --no-browser

benchmark: ## [both] Precision@10 (keyword/semantic/hybrid) + P99 latency table
	@$(PY) scripts/benchmark.py

test: ## [both] Run pytest (app + scripts)
	@$(PYTEST) -q

clean-lite: ## [lite] Wipe venv + data + Feast registry
ifeq ($(OS),Windows_NT)
	-@rmdir /s /q $(VENV) data\qdrant_storage app\feast_repo\data notebooks\.ipynb_checkpoints 2>nul || true
	-@del /q data\corpus_vn.jsonl data\golden_set.jsonl app\feast_repo\registry.db app\feast_repo\online_store.db notebooks\*.ipynb 2>nul || true
else
	rm -rf $(VENV) data/corpus_vn.jsonl data/golden_set.jsonl data/qdrant_storage \
	       app/feast_repo/data app/feast_repo/registry.db app/feast_repo/online_store.db \
	       notebooks/*.ipynb notebooks/.ipynb_checkpoints
endif

# ─────────────────────────────────────────────────────────────
# Docker path (full stack: Qdrant + Redis + Postgres)
# ─────────────────────────────────────────────────────────────

setup-docker: ## [docker] Bring up Docker stack + venv + seed + smoke test
	@$(SETUP_DOCKER)

verify-docker: ## [docker] Verify all 3 services reachable + Feast wired
	@$(PY) scripts/verify_docker.py

docker-up: ## [docker] Just bring services up (no venv changes)
	docker compose up -d

docker-down: ## [docker] Stop services (data persists)
	docker compose down

docker-clean: ## [docker] Stop AND wipe Qdrant + Redis + Postgres volumes
	docker compose down -v

.PHONY: help setup-lite verify-lite seed api lab benchmark test clean-lite \
        setup-docker verify-docker docker-up docker-down docker-clean

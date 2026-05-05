param (
    [Parameter(Position=0)]
    [string]$Target = "help"
)

$VENV = ".venv"
$PY = "$VENV\Scripts\python.exe"
$PIP = "$VENV\Scripts\pip.exe"
$JUPYTER = "$VENV\Scripts\jupyter.exe"
$JUPYTEXT = "$VENV\Scripts\jupytext.exe"
$UVICORN = "$VENV\Scripts\uvicorn.exe"
$PYTEST = "$VENV\Scripts\pytest.exe"

switch ($Target) {
    "help" {
        Write-Host "Usage:"
        Write-Host "  .\make.ps1 <target>`n"
        Write-Host "Lightweight path (default):"
        Write-Host "  setup-lite       [lite] Create venv + install + seed corpus + smoke test"
        Write-Host "  verify-lite      [lite] 5-second smoke test (Qdrant memory + BM25 + Feast SQLite)"
        Write-Host "  seed             [both] (Re)generate data/corpus_vn.jsonl + data/golden_set.jsonl"
        Write-Host "  api              [lite] Start FastAPI /search on http://localhost:8000"
        Write-Host "  lab              [lite] Open Jupyter Lab on http://localhost:8888"
        Write-Host "  benchmark        [both] Precision@10 (keyword/semantic/hybrid) + P99 latency table"
        Write-Host "  test             [both] Run pytest (app + scripts)"
        Write-Host "  clean-lite       [lite] Wipe venv + data + Feast registry`n"
        Write-Host "Docker path:"
        Write-Host "  setup-docker     [docker] Bring up Docker stack + venv + seed + smoke test"
        Write-Host "  verify-docker    [docker] Verify all 3 services reachable + Feast wired"
        Write-Host "  docker-up        [docker] Just bring services up (no venv changes)"
        Write-Host "  docker-down      [docker] Stop services (data persists)"
        Write-Host "  docker-clean     [docker] Stop AND wipe Qdrant + Redis + Postgres volumes"
    }
    "setup-lite" {
        if (Test-Path "setup-lite.ps1") { .\setup-lite.ps1 } else { .\setup-lite.bat }
    }
    "verify-lite" {
        & $PY scripts/verify_lite.py
    }
    "seed" {
        & $PY scripts/seed_corpus.py
    }
    "api" {
        & $UVICORN app.main:app --reload --port 8000
    }
    "lab" {
        & $JUPYTEXT --to notebook --update notebooks/*.py 2>$null
        & $JUPYTER lab --notebook-dir=notebooks --ServerApp.token='' --no-browser
    }
    "benchmark" {
        & $PY scripts/benchmark.py
    }
    "test" {
        & $PYTEST -q
    }
    "clean-lite" {
        $items = @(
            $VENV, "data/corpus_vn.jsonl", "data/golden_set.jsonl", "data/qdrant_storage",
            "app/feast_repo/data", "app/feast_repo/registry.db", "app/feast_repo/online_store.db",
            "notebooks/.ipynb_checkpoints"
        )
        foreach ($item in $items) {
            if (Test-Path $item) { Remove-Item -Recurse -Force $item }
        }
        if (Test-Path "notebooks/*.ipynb") { Remove-Item -Force notebooks/*.ipynb }
    }
    "setup-docker" {
        if (Test-Path "setup-docker.ps1") { .\setup-docker.ps1 } elseif (Test-Path "setup-docker.bat") { .\setup-docker.bat } else { Write-Host "setup-docker script not found." }
    }
    "verify-docker" {
        & $PY scripts/verify_docker.py
    }
    "docker-up" {
        docker compose up -d
    }
    "docker-down" {
        docker compose down
    }
    "docker-clean" {
        docker compose down -v
    }
    default {
        Write-Host "Unknown target: $Target"
        Write-Host "Run '.\make.ps1 help' to see available targets."
    }
}

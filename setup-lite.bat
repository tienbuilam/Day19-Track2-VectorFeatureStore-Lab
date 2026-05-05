@echo off
setlocal enabledelayedexpansion

echo [lite] Day 19 lightweight setup
echo [lite] Stack: fastembed + qdrant-client[memory] + rank-bm25 + feast(sqlite) + FastAPI
echo.

:: ── 1. Python ───────────────────────────────────────────────────────────
where python >nul 2>nul
if %errorlevel% neq 0 (
    echo [lite] python not found. Install Python 3.10+.
    exit /b 1
)
for /f "tokens=*" %%i in ('python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"') do set PY_VER=%%i
echo [lite] Python %PY_VER% detected

:: ── 2. venv ─────────────────────────────────────────────────────────────
if not exist .venv (
    where uv >nul 2>nul
    if !errorlevel! equ 0 (
        echo [lite] Creating venv with uv (faster^)
        uv venv .venv
    ) else (
        echo [lite] Creating venv with python -m venv
        python -m venv .venv
    )
)

:: Activate venv
call .venv\Scripts\activate.bat

:: ── 3. Install deps ─────────────────────────────────────────────────────
where uv >nul 2>nul
if %errorlevel% equ 0 (
    uv pip install -r requirements.txt
) else (
    python -m pip install -q -U pip
    python -m pip install -q -r requirements.txt
)

:: ── 4. Convert Jupytext sources to .ipynb ───────────────────────────────
jupytext --to notebook --update notebooks/*.py 2>nul
if %errorlevel% neq 0 (
    jupytext --to notebook notebooks/*.py
)

:: ── 5. .env scaffold ────────────────────────────────────────────────────
if not exist .env (
    copy .env.example .env >nul
)

:: ── 6. Seed corpus + golden set ─────────────────────────────────────────
python scripts/seed_corpus.py

:: ── 7. Smoke test ───────────────────────────────────────────────────────
python scripts/verify_lite.py

echo.
echo [lite] Done. Activate the venv and start working:
echo.
echo     .venv\Scripts\activate
echo     make api       # start FastAPI on :8000
echo     make lab       # open Jupyter on :8888
echo     make benchmark # Precision@10 + latency table
echo.
echo Tip: read VIBE-CODING.md before starting NB1 -- it tells you what to delegate
echo to your AI assistant and what to think through yourself.

#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${PROJECT_ROOT}/rag_api"

python3 -m venv "${APP_DIR}/.venv"
source "${APP_DIR}/.venv/bin/activate"

pip install --upgrade pip
pip install -r "${APP_DIR}/requirements.txt"

uvicorn app:app --host 0.0.0.0 --port 8080 --reload

#!/usr/bin/env bash
# Añade DBT_PROFILES_DIR al activate del venv para poder hacer
#   cd transform && dbt run
# sin --profiles-dir. Idempotente.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTIVATE="$ROOT/.venv/bin/activate"
MARKER="# >>> alohas dbt profiles"

if [[ ! -f "$ACTIVATE" ]]; then
  echo "No hay .venv; crea el venv antes." >&2
  exit 1
fi

if grep -q "$MARKER" "$ACTIVATE"; then
  exit 0
fi

cat >> "$ACTIVATE" <<'INNER'

# >>> alohas dbt profiles
# activate vive en .venv/bin/ → subir dos niveles hasta la raíz del repo
_ALOHAS_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DBT_PROFILES_DIR="$_ALOHAS_REPO_ROOT/transform"
# <<< alohas dbt profiles
INNER

echo "Patched $ACTIVATE (DBT_PROFILES_DIR -> transform/)"

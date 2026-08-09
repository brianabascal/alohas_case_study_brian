#!/usr/bin/env python3
"""Extrae las tablas de production a data/raw/*.csv (solo lectura).

Reutiliza el runner REST de scripts/bq.py: Viewer + Job User no permiten
Storage Read API ni materializar en el proyecto de Alohas.

Uso (desde la raiz del repo, con ADC activo):
    python3 scripts/extract.py
    python3 scripts/extract.py --dry-run
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

# Reutilizar el cliente de solo lectura del repo
sys.path.insert(0, str(Path(__file__).resolve().parent))
from bq import DEFAULT_MAX_BYTES, PROJECT, access_token, run  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "data" / "raw"

# Nombre de fichero = nombre de tabla (sources dbt usan {name}.csv)
TABLES = (
    "dim_product",
    "fct_shipment",
    "fct_sale_order_line",
)

DATASET = "production"


def extract_table(name: str, token: str, dry_run: bool, max_bytes: int) -> int:
    sql = f"SELECT * FROM `{PROJECT}.{DATASET}.{name}`"
    out = OUT_DIR / f"{name}.csv"
    columns, rows = run(sql, token, dry_run, max_bytes)
    if dry_run:
        print(f"[extract] dry-run OK: {name}", file=sys.stderr)
        return 0

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        writer.writerow(columns)
        writer.writerows(rows)
    print(f"[extract] {len(rows):,} filas -> {out.relative_to(ROOT)}", file=sys.stderr)
    return len(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES)
    parser.add_argument(
        "--only",
        choices=TABLES,
        action="append",
        help="extraer solo esta tabla (repetible)",
    )
    args = parser.parse_args()

    tables = tuple(args.only) if args.only else TABLES
    token = access_token()
    total = 0
    for name in tables:
        total += extract_table(name, token, args.dry_run, args.max_bytes)
    if not args.dry_run:
        print(f"[extract] listo: {total:,} filas en {OUT_DIR.relative_to(ROOT)}/", file=sys.stderr)


if __name__ == "__main__":
    main()

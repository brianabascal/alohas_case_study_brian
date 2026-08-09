#!/usr/bin/env python3
"""Runner de consultas de solo lectura contra el BigQuery de Alohas.

Usa el ADC de la cuenta personal (scope bigquery.readonly), habla directamente
con la REST API y no necesita dependencias fuera de la stdlib. Existe porque el
rol concedido es Viewer + Job User: no se pueden crear tablas ni usar la Storage
Read API, asi que todo sale por jobs.query paginado.

Uso:
    python3 scripts/bq.py analysis/audit/01_algo.sql
    python3 scripts/bq.py --sql "SELECT 1"
    python3 scripts/bq.py --dry-run analysis/audit/01_algo.sql
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

PROJECT = "alohas-recruiting-study-case"
LOCATION = "EU"
DEFAULT_MAX_BYTES = 1_073_741_824  # 1 GiB, mismo cap que el servidor MCP
API = "https://bigquery.googleapis.com/bigquery/v2"


def access_token() -> str:
    out = subprocess.run(
        ["gcloud", "auth", "application-default", "print-access-token"],
        capture_output=True,
        text=True,
    )
    if out.returncode != 0:
        sys.exit(
            "No hay credenciales ADC validas. Ejecuta:\n"
            "  gcloud auth application-default login --scopes=openid,"
            "https://www.googleapis.com/auth/userinfo.email,"
            "https://www.googleapis.com/auth/cloud-platform,"
            "https://www.googleapis.com/auth/bigquery.readonly"
        )
    return out.stdout.strip()


def call(url: str, token: str, payload: dict | None = None) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST" if data else "GET",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as err:
        detail = json.loads(err.read() or b"{}")
        message = detail.get("error", {}).get("message", str(err))
        sys.exit(f"BigQuery devolvio {err.code}: {message}")


def flatten(value):
    """Aplana el formato f/v de la API. Las tablas del caso son planas."""
    if isinstance(value, dict) and "v" in value:
        return flatten(value["v"])
    if isinstance(value, list):
        return json.dumps([flatten(v) for v in value], ensure_ascii=False)
    if isinstance(value, dict):
        return json.dumps(value, ensure_ascii=False)
    return value


def to_iso_utc(value):
    """La REST API devuelve los TIMESTAMP como segundos epoch ('1.7378902E9').

    Escrito asi en un CSV no hay motor que lo lea como fecha, y quien abra el
    fichero no sabe que esta mirando. Se guarda en UTC y con precision de
    segundo, que es la que trae el dataset.
    """
    if value in (None, ""):
        return value
    return datetime.fromtimestamp(float(value), tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def read_rows(payload: dict, types: list[str]) -> list[list]:
    return [
        [
            to_iso_utc(flatten(cell)) if kind == "TIMESTAMP" else flatten(cell)
            for cell, kind in zip(row["f"], types)
        ]
        for row in payload.get("rows", [])
    ]


def run(sql: str, token: str, dry_run: bool, max_bytes: int) -> tuple[list[str], list[list]]:
    body = {
        "query": sql,
        "useLegacySql": False,
        "location": LOCATION,
        "maximumBytesBilled": str(max_bytes),
        "dryRun": dry_run,
        "timeoutMs": 120_000,
    }
    result = call(f"{API}/projects/{PROJECT}/queries", token, body)

    scanned = int(result.get("totalBytesProcessed", 0))
    print(f"[bq] escaneados {scanned / 1e6:.2f} MB", file=sys.stderr)
    if dry_run:
        return [], []

    fields = result.get("schema", {}).get("fields", [])
    columns = [f["name"] for f in fields]
    types = [f.get("type") for f in fields]
    rows = read_rows(result, types)

    job_id = result["jobReference"]["jobId"]
    token_page = result.get("pageToken")
    while token_page:
        page = call(
            f"{API}/projects/{PROJECT}/queries/{job_id}"
            f"?location={LOCATION}&pageToken={token_page}",
            token,
        )
        rows += read_rows(page, types)
        token_page = page.get("pageToken")

    return columns, rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("file", nargs="?", help="fichero .sql a ejecutar")
    parser.add_argument("--sql", help="SQL inline en lugar de fichero")
    parser.add_argument("--dry-run", action="store_true", help="solo valida y estima coste")
    parser.add_argument("--out", help="ruta del CSV de salida")
    parser.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES)
    args = parser.parse_args()

    if args.sql:
        sql = args.sql
    elif args.file:
        sql = open(args.file, encoding="utf-8").read()
    else:
        sql = sys.stdin.read()

    columns, rows = run(sql, access_token(), args.dry_run, args.max_bytes)
    if args.dry_run:
        return

    writer = csv.writer(open(args.out, "w", newline="", encoding="utf-8") if args.out else sys.stdout)
    writer.writerow(columns)
    writer.writerows(rows)
    if args.out:
        print(f"[bq] {len(rows)} filas -> {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()

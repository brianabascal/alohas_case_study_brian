"""Curva de llegada de devoluciones — asunción declarada de la sección 02.

No es una medición del dataset (DQ-08: las devoluciones ya llegaron todas).
Reparte el único evento de devolución de cada línea a lo largo de 30–90 días
con pico a 45, de forma determinista, para ilustrar as-of return date.

Uso: importado por report/build_report.py al dibujar los charts de la 02.
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import date, timedelta
from functools import lru_cache
from typing import Iterable

import duckdb

# Ventana del brief; la forma evita llegada uniforme.
LAG_MIN = 30
LAG_PEAK = 45
LAG_MAX = 90

# Mes de venta usado en el sketch "mismo mes medido en el tiempo".
SKETCH_SALE_MONTH = date(2025, 1, 1)

# Corte del dataset en hora de Barcelona (D-17).
CUTOFF = date(2026, 5, 30)


@dataclass(frozen=True)
class ReturnEvent:
    sale_date: date
    sale_month: date
    returned_at: date
    return_month: date
    quantity: int
    returned_revenue: float
    revenue_ex_tax: float


def _triangle_weight(lag: int) -> float:
    """Peso triangular en [LAG_MIN, LAG_MAX] con pico en LAG_PEAK.

    Los extremos llevan un 10% de la altura del pico para que el día 30 (inicio
    de la ventana del brief) no quede en masa cero.
    """
    if lag < LAG_MIN or lag > LAG_MAX:
        return 0.0
    if lag <= LAG_PEAK:
        t = (lag - LAG_MIN) / (LAG_PEAK - LAG_MIN)
    else:
        t = (LAG_MAX - lag) / (LAG_MAX - LAG_PEAK)
    return 0.1 + 0.9 * t


@lru_cache(maxsize=1)
def _lag_table() -> tuple[tuple[int, float], ...]:
    """(lag_days, cdf_acumulada) para muestreo determinista por percentil."""
    weights = [(lag, _triangle_weight(lag)) for lag in range(LAG_MIN, LAG_MAX + 1)]
    total = sum(w for _, w in weights)
    cdf = []
    running = 0.0
    for lag, w in weights:
        running += w / total
        cdf.append((lag, running))
    # Garantizar que el último es exactamente 1.
    last_lag, _ = cdf[-1]
    cdf[-1] = (last_lag, 1.0)
    return tuple(cdf)


def maturity_cdf(days: int) -> float:
    """Fracción de devoluciones ya aterrizadas a `days` días tras la venta."""
    if days < LAG_MIN:
        return 0.0
    if days >= LAG_MAX:
        return 1.0
    for lag, cdf in _lag_table():
        if lag >= days:
            return cdf
    return 1.0


def maturity_milestones() -> list[tuple[int, float]]:
    return [(d, maturity_cdf(d)) for d in (30, 45, 60, 90, 120)]


def _u01(key: str) -> float:
    """Uniforme [0, 1) determinista a partir de una clave estable."""
    digest = hashlib.md5(key.encode("utf-8")).hexdigest()
    return int(digest[:12], 16) / float(16**12)


def lag_for_key(key: str) -> int:
    """Lag en días (30–90) a partir del percentil del hash."""
    u = _u01(key)
    for lag, cdf in _lag_table():
        if u <= cdf:
            return lag
    return LAG_MAX


def _month_start(d: date) -> date:
    return date(d.year, d.month, 1)


def load_return_events(con: duckdb.DuckDBPyConnection) -> list[ReturnEvent]:
    """Una fila por order line con devolución: un solo evento de N unidades."""
    rows = con.sql("""
        select
            sale_order_line_sk,
            sale_date,
            sale_month,
            quantity_returned,
            cast(returned_revenue as double) as returned_revenue,
            cast(revenue_ex_tax as double) as revenue_ex_tax
        from fct_sale_line
        where quantity_returned > 0
    """).fetchall()

    events: list[ReturnEvent] = []
    for sk, sale_date, sale_month, qty, ret_rev, rev in rows:
        lag = lag_for_key(str(sk))
        returned_at = sale_date + timedelta(days=lag)
        events.append(
            ReturnEvent(
                sale_date=sale_date,
                sale_month=sale_month,
                returned_at=returned_at,
                return_month=_month_start(returned_at),
                quantity=int(qty),
                returned_revenue=float(ret_rev),
                revenue_ex_tax=float(rev),
            )
        )
    return events


def load_monthly_sales(
    con: duckdb.DuckDBPyConnection,
) -> list[tuple[date, float, bool]]:
    """(sale_month, revenue_ex_tax, is_partial_month) para todos los meses."""
    return [
        (m, float(rev), bool(partial))
        for m, rev, partial in con.sql("""
            select
                sale_month,
                cast(sum(revenue_ex_tax) as double),
                bool_or(is_partial_month)
            from fct_sale_line
            group by sale_month
            order by sale_month
        """).fetchall()
    ]


def net_of_sale_month_as_of(
    sale_month: date,
    as_of: date,
    monthly_sales: Iterable[tuple[date, float, bool]],
    events: Iterable[ReturnEvent],
) -> float:
    """Ingreso neto del mes de venta visto en `as_of` (as-of report date).

    Resta solo las devoluciones de ese mes de venta cuyo returned_at <= as_of.
    """
    revenue = next(rev for m, rev, _ in monthly_sales if m == sale_month)
    returned = sum(
        e.returned_revenue
        for e in events
        if e.sale_month == sale_month and e.returned_at <= as_of
    )
    return revenue - returned


def cash_net_for_month(
    month: date,
    monthly_sales: Iterable[tuple[date, float, bool]],
    events: Iterable[ReturnEvent],
    *,
    as_of: date | None = None,
) -> float:
    """Ingreso neto de caja del mes: ventas del mes − devoluciones con returned_at en el mes.

    Si `as_of` se pasa, solo cuenta eventos ya conocidos en esa fecha (para
    ilustrar la cola aún no aterrizada desde el punto de vista de hoy).
    """
    sales = next((rev for m, rev, _ in monthly_sales if m == month), 0.0)
    returned = 0.0
    for e in events:
        if e.return_month != month:
            continue
        if as_of is not None and e.returned_at > as_of:
            continue
        returned += e.returned_revenue
    return sales - returned


def sketch_sale_month_rewrite(
    con: duckdb.DuckDBPyConnection,
    sale_month: date = SKETCH_SALE_MONTH,
) -> list[tuple[date, float]]:
    """Neto del mes de venta en fechas de report sucesivas (la mentira)."""
    monthly = load_monthly_sales(con)
    events = load_return_events(con)
    # Día siguiente al fin del mes de venta, luego +30, +60, +90, +180.
    if sale_month.month == 12:
        month_end = date(sale_month.year + 1, 1, 1) - timedelta(days=1)
    else:
        month_end = date(sale_month.year, sale_month.month + 1, 1) - timedelta(days=1)

    offsets = (0, 30, 60, 90, 180)
    points = []
    for days in offsets:
        as_of = month_end + timedelta(days=days)
        points.append((as_of, net_of_sale_month_as_of(sale_month, as_of, monthly, events)))
    return points


def sketch_sale_month_stable_and_debits(
    con: duckdb.DuckDBPyConnection,
    sale_month: date = SKETCH_SALE_MONTH,
) -> tuple[float, list[tuple[date, float]]]:
    """Bajo as-of return date: neto de venta del mes (estable) + débitos por mes de aterrizaje."""
    monthly = load_monthly_sales(con)
    events = [e for e in load_return_events(con) if e.sale_month == sale_month]
    revenue = next(rev for m, rev, _ in monthly if m == sale_month)
    # Cohorte congelada al cierre = revenue sin restar (las devoluciones van a otros meses).
    # Para el panel "venta estable" mostramos revenue_ex_tax del mes (bruto de caja de ventas);
    # el neto de cohorte final sería revenue - sum(returns), pero el punto es que NO se reescribe.
    sale_month_cash_in = revenue

    by_return_month: dict[date, float] = {}
    for e in events:
        by_return_month[e.return_month] = (
            by_return_month.get(e.return_month, 0.0) + e.returned_revenue
        )
    debits = sorted(by_return_month.items())
    return sale_month_cash_in, debits


def cash_monthly_series(
    con: duckdb.DuckDBPyConnection,
    *,
    as_of: date = CUTOFF,
) -> list[tuple[date, float, bool]]:
    """Serie de caja cerrada: ventas − devoluciones aterrizadas en cada mes.

    No existe una segunda versión "madura": bajo as-of return date, cada
    devolución entra una vez en el mes en que ocurre y los meses anteriores no
    se reescriben.
    """
    monthly = load_monthly_sales(con)
    events = load_return_events(con)
    series = []
    for month, _rev, partial in monthly:
        cash_net = cash_net_for_month(month, monthly, events, as_of=as_of)
        series.append((month, cash_net, partial))
    return series


def returns_landing_in_month(
    con: duckdb.DuckDBPyConnection,
) -> list[tuple[date, float]]:
    """Valor devuelto agregado por mes de aterrizaje (ilustración)."""
    totals: dict[date, float] = {}
    for e in load_return_events(con):
        totals[e.return_month] = totals.get(e.return_month, 0.0) + e.returned_revenue
    return sorted(totals.items())

#!/usr/bin/env python3
"""Renderiza el report a HTML autocontenido que se abre en el navegador.

La narrativa vive en los `.md` de la raiz del repo. La seccion 01 lee los marts
de dbt (aqui no se calcula nada de negocio). La seccion 02 es una propuesta de
esquema; sus graficos de madurez son ilustraciones con la curva declarada en
`curva_devoluciones.py`.

El HTML lleva plotly incrustado, asi que funciona sin conexion y se puede mandar
por correo como un fichero suelto.

Uso (desde la raiz del repo, con los marts ya construidos):
    python3 report/build_report.py
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

import duckdb
import markdown
import plotly.graph_objects as go
import plotly.offline
from plotly.subplots import make_subplots

from curva_devoluciones import (
    SKETCH_SALE_MONTH,
    cash_monthly_series,
    maturity_milestones,
    sketch_sale_month_rewrite,
    sketch_sale_month_stable_and_debits,
)

ROOT = Path(__file__).resolve().parents[1]
DATABASE = ROOT / "data" / "alohas.duckdb"
REPORT_DIR = ROOT / "report"


@dataclass(frozen=True)
class Document:
    """Un HTML de salida alimentado por uno o varios .md de la raíz."""

    filename: str
    sections: tuple[str, ...]
    title: str
    headline: str
    meta_suffix: str
    footer: str


DOCUMENTS = (
    Document(
        filename="report_v1.html",
        sections=(
            "archivo/seccion_01_canales_report.md",
            "archivo/seccion_02_hipotesis_report.md",
        ),
        title="ALOHAS · case study de Analytics Engineer",
        headline="ALOHAS · cómo se mide este negocio",
        meta_suffix="secciones publicadas: 2 de 3",
        footer=(
            "Generado con <code>report/build_report.py</code>. La sección 01 lee "
            "marts <code>rpt_*</code>; la 02 es una propuesta de esquema y sus "
            "gráficos de madurez son ilustraciones "
            "(<code>report/curva_devoluciones.py</code>), no una medición del "
            "dataset."
        ),
    ),
    Document(
        filename="index_03.html",
        sections=("seccion_03_margen_report.md",),
        title="ALOHAS · contribution margin",
        headline="ALOHAS · quién gana dinero de verdad",
        meta_suffix="sección 03 · contribution margin",
        footer=(
            "Generado con <code>report/build_report.py</code>. "
            "Marts <code>rpt_*_contribution</code> y seed "
            "<code>channel_economics</code>."
        ),
    ),
)

# Los .md se enlazan entre si con rutas relativas para que funcionen leyendolos en
# GitHub. En el HTML esas rutas no llevan a ninguna parte, asi que al renderizar se
# reescriben contra el repositorio.
REPO = "https://github.com/brianabascal/alohas_case_study_brian/blob/main"

# Un color por canal, el mismo en todos los graficos: el lector no deberia tener
# que releer la leyenda en cada figura.
COLORS = {
    "online": "#2563eb",
    "retail": "#16a34a",
    "wholesale": "#d97706",
    "marketplace": "#9333ea",
}
INK = "#1f2933"

FONT = "system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"


# --------------------------------------------------------------------------- #
# Formato
# --------------------------------------------------------------------------- #

def eur(value) -> str:
    """1234567.8 -> '1.234.568 €'."""
    return f"{float(value):,.0f}".replace(",", ".") + " €"


def pct(value, decimals: int = 1) -> str:
    """22.48 -> '22,5%'."""
    return f"{float(value):.{decimals}f}".replace(".", ",") + "%"


# --------------------------------------------------------------------------- #
# Graficos
# --------------------------------------------------------------------------- #

def base_layout(
    fig: go.Figure,
    height: int = 400,
    top_margin: int = 50,
    bottom_margin: int = 10,
) -> go.Figure:
    fig.update_layout(
        height=height,
        font=dict(family=FONT, size=13, color=INK),
        plot_bgcolor="white",
        paper_bgcolor="white",
        margin=dict(l=10, r=10, t=top_margin, b=bottom_margin),
        title=dict(font=dict(size=15), x=0, xanchor="left"),
        # Formato espanol: coma decimal y punto de millares.
        separators=",.",
        hoverlabel=dict(font=dict(family=FONT, size=12)),
        legend=dict(
            orientation="h", yanchor="bottom", y=1.0, x=0, title=None,
            # Sin esto plotly invierte la leyenda de las barras apiladas.
            traceorder="normal",
        ),
    )
    fig.update_xaxes(showgrid=False, linecolor="#dfe3e8", ticks="outside", tickcolor="#dfe3e8")
    fig.update_yaxes(showgrid=True, gridcolor="#eef1f4", zeroline=False)
    return fig


def chart_escalera(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """De lo que paga el cliente a lo que de verdad ingresa el negocio."""
    gross, taxes, returned, net = con.sql("""
        select gross_charged, taxes, returned_revenue, net_revenue
        from rpt_channel_revenue_ladder where channel = 'TODOS'
    """).fetchone()

    fig = go.Figure(go.Waterfall(
        orientation="v",
        measure=["absolute", "relative", "relative", "total"],
        x=["Importe cobrado", "Impuestos", "Valor devuelto", "Ingreso neto"],
        y=[float(gross), -float(taxes), -float(returned), 0],
        text=[eur(gross), "−" + eur(taxes), "−" + eur(returned), eur(net)],
        textposition="outside",
        connector=dict(line=dict(color="#dfe3e8")),
        increasing=dict(marker=dict(color="#2563eb")),
        decreasing=dict(marker=dict(color="#e4572e")),
        totals=dict(marker=dict(color="#111827")),
        hovertemplate="%{x}: %{text}<extra></extra>",
    ))
    fig.update_layout(title="De cada 100 € cobrados quedan 70,28 € de ingreso neto")
    fig.update_yaxes(tickformat=",.0f", ticksuffix=" €", rangemode="tozero")
    return base_layout(fig, 420)


def chart_peldanos(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """La misma realidad ordenada de tres formas distintas.

    Aqui el color es el peldano y no el canal: lo que se compara son las tres
    lecturas del mismo negocio, no los canales entre si.
    """
    rows = con.sql("""
        select channel, share_of_gross_pct, share_of_ex_tax_pct, share_of_net_pct
        from rpt_channel_revenue_ladder
        where channel <> 'TODOS'
        order by share_of_net_pct desc
    """).fetchall()

    peldanos = [
        ("Lo cobrado", 1, "#cbd5e1"),
        ("Sin impuesto", 2, "#7b8ca3"),
        ("Ingreso neto", 3, "#1f2933"),
    ]
    fig = go.Figure()
    for label, column, color in peldanos:
        fig.add_trace(go.Bar(
            name=label,
            x=[r[0] for r in rows],
            y=[r[column] for r in rows],
            marker=dict(color=color),
            text=[pct(r[column]) for r in rows],
            textposition="outside",
            hovertemplate="%{x} · " + label + ": %{y:.2f}%<extra></extra>",
        ))
    fig.update_layout(
        title="Cuota de cada canal en los tres peldaños de la escalera",
        barmode="group",
        bargap=0.35,
    )
    fig.update_yaxes(ticksuffix="%", range=[0, 68])
    return base_layout(fig, 420)


def chart_mensual(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """La serie que un CEO mira primero, sin los dos meses incompletos."""
    fig = go.Figure()
    for channel in ("online", "retail", "wholesale", "marketplace"):
        rows = con.sql("""
            select sale_month, net_revenue
            from rpt_channel_monthly
            where channel = ? and not is_partial_month
            order by sale_month
        """, params=[channel]).fetchall()
        fig.add_trace(go.Scatter(
            x=[r[0] for r in rows],
            y=[float(r[1]) for r in rows],
            name=channel,
            mode="lines",
            line=dict(color=COLORS[channel], width=2.5),
            hovertemplate="%{fullData.name} · %{x|%m/%Y}: %{y:,.0f} €<extra></extra>",
        ))
    fig.update_layout(
        title="Ingreso neto por canal y mes · junio 2024 – abril 2026, meses completos",
    )
    fig.update_yaxes(tickformat=",.0f", ticksuffix=" €", rangemode="tozero")
    fig.update_xaxes(tickformat="%m/%Y", dtick="M3")
    return base_layout(fig, 420)


def chart_yoy(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """El mismo crecimiento en euros y en porcentaje, uno al lado del otro.

    Hacen falta los dos paneles: en euros los canales no se parecen en nada, y en
    porcentaje se parecen tanto que la mezcla no se mueve. Cada panel solo cuenta
    la mitad de la historia.
    """
    rows = con.sql("""
        select channel, net_revenue_y1, net_revenue_y2, net_revenue_growth_pct
        from rpt_channel_growth
        where channel <> 'TODOS'
        order by net_revenue_y2
    """).fetchall()
    (media,) = con.sql("""
        select net_revenue_growth_pct from rpt_channel_growth where channel = 'TODOS'
    """).fetchone()

    canales = [r[0] for r in rows]
    fig = make_subplots(rows=1, cols=2, shared_yaxes=True,
                        horizontal_spacing=0.06, column_widths=[0.62, 0.38])

    for label, column, color in (("Año 1", 1, "#cbd5e1"), ("Año 2", 2, "#1f2933")):
        fig.add_trace(go.Bar(
            name=label,
            orientation="h",
            y=canales,
            x=[float(r[column]) for r in rows],
            marker=dict(color=color),
            text=[eur(r[column]) for r in rows],
            textposition="outside",
            textfont=dict(size=11),
            hovertemplate="%{y} · " + label + ": %{x:,.0f} €<extra></extra>",
        ), row=1, col=1)

    fig.add_trace(go.Bar(
        showlegend=False,
        orientation="h",
        y=canales,
        x=[float(r[3]) for r in rows],
        marker=dict(color=[COLORS[c] for c in canales]),
        text=["+" + pct(r[3]) for r in rows],
        textposition="outside",
        textfont=dict(size=11),
        hovertemplate="%{y}: +%{x:.2f}% sobre el año anterior<extra></extra>",
    ), row=1, col=2)

    fig.add_vline(x=float(media), row=1, col=2, line=dict(color="#9aa5b1", dash="dot"))

    fig.update_layout(
        title=(
            "Ingreso neto de cada canal, año 1 contra año 2"
            "<br><span style='font-size:12px'>La línea de puntos es el crecimiento"
            f" del negocio entero, +{pct(media)}</span>"
        ),
        barmode="group",
        bargap=0.35,
    )
    fig.update_yaxes(showgrid=False)
    eje = dict(title_font=dict(size=11, color="#6b7280"))
    fig.update_xaxes(
        title_text="ingreso neto del año", tickformat=",.0f", ticksuffix=" €",
        range=[0, max(float(r[2]) for r in rows) * 1.42], row=1, col=1, **eje,
    )
    fig.update_xaxes(
        title_text="crecimiento sobre el año anterior", ticksuffix="%",
        range=[0, 30], row=1, col=2, **eje,
    )
    return base_layout(fig, 400, top_margin=105, bottom_margin=45)


def chart_crecimiento(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """Crecer rapido y mover dinero no son lo mismo."""
    rows = con.sql("""
        select channel, net_revenue_growth_eur, net_revenue_growth_pct, share_of_growth_pct
        from rpt_channel_growth
        where channel <> 'TODOS'
        order by net_revenue_growth_eur
    """).fetchall()

    fig = go.Figure(go.Bar(
        orientation="h",
        x=[float(r[1]) for r in rows],
        y=[r[0] for r in rows],
        marker=dict(color=[COLORS[r[0]] for r in rows]),
        text=[f"{eur(r[1])}  ·  +{pct(r[2])}  ·  {pct(r[3], 0)} del total" for r in rows],
        textposition="outside",
        hovertemplate="%{y}: %{text}<extra></extra>",
    ))
    fig.update_layout(
        title="Euros de crecimiento que aporta cada canal · online pone el 58,7%",
    )
    fig.update_xaxes(tickformat=",.0f", ticksuffix=" €", range=[0, 900_000])
    fig.update_yaxes(showgrid=False)
    return base_layout(fig, 340)


def chart_devoluciones(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """Un deterioro de verdad sube tramo tras tramo. Ninguno lo hace."""
    tramos = con.sql("""
        select distinct half_number, half_start, half_end
        from rpt_channel_returns_trend
        order by half_number
    """).fetchall()
    etiquetas = [f"{start:%m/%y} – {end:%m/%y}" for _, start, end in tramos]

    fig = go.Figure()
    for channel in ("online", "marketplace", "retail", "wholesale"):
        rows = con.sql("""
            select return_rate_pct, units_sold, units_returned
            from rpt_channel_returns_trend
            where channel = ?
            order by half_number
        """, params=[channel]).fetchall()
        fig.add_trace(go.Scatter(
            name=channel,
            x=etiquetas,
            y=[float(r[0]) for r in rows],
            mode="lines+markers",
            line=dict(color=COLORS[channel], width=2.5),
            marker=dict(size=8),
            customdata=[(r[2], r[1]) for r in rows],
            hovertemplate=(
                "%{fullData.name} · %{x}: %{y:.2f}%"
                "<br>%{customdata[0]} prendas devueltas de %{customdata[1]}<extra></extra>"
            ),
        ))
    fig.update_layout(
        title=(
            "Unidades devueltas sobre vendidas, medio año a medio año"
            "<br><span style='font-size:12px'>Un deterioro se vería como una línea"
            " que sube tramo tras tramo</span>"
        ),
    )
    fig.update_yaxes(ticksuffix="%", range=[0, 21])
    return base_layout(fig, 420, top_margin=105)


def chart_estacionalidad(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """Cuánto del periodo cabe en Black Friday y Navidad, canal a canal.

    Sale del mart mensual sin modelo nuevo: solo separa los meses de pico del
    resto. Los meses incompletos quedan fuera, así que el reparto se juega entre
    los 23 meses completos y cuatro de ellos son noviembre o diciembre.
    """
    rows = con.sql("""
        select
            channel,
            100.0 * sum(net_revenue) filter (where month(sale_month) in (11, 12))
                / sum(net_revenue) as pico_pct,
            count(*) filter (where month(sale_month) in (11, 12)) as meses_pico,
            count(*) as meses,
            avg(net_revenue) filter (where month(sale_month) in (11, 12)) as media_pico,
            avg(net_revenue) filter (where month(sale_month) not in (11, 12)) as media_resto
        from rpt_channel_monthly
        where not is_partial_month
        group by channel
        order by pico_pct
    """).fetchall()

    canales = [r[0] for r in rows]
    pico = [float(r[1]) for r in rows]
    # Lo que pesarían cuatro meses si todos los meses vendieran lo mismo.
    plano = 100.0 * rows[0][2] / rows[0][3]

    fig = go.Figure()
    fig.add_trace(go.Bar(
        name="Noviembre y diciembre",
        orientation="h",
        y=canales,
        x=pico,
        marker=dict(color=INK),
        text=[pct(v) for v in pico],
        textposition="inside",
        insidetextanchor="middle",
        textfont=dict(color="white", size=12),
        customdata=[(float(r[4]), float(r[5]), float(r[4]) / float(r[5])) for r in rows],
        hovertemplate=(
            "%{y} · noviembre y diciembre: %{x:.1f}% del ingreso neto"
            "<br>%{customdata[0]:,.0f} € al mes frente a %{customdata[1]:,.0f} €"
            " en los demás meses (%{customdata[2]:.2f} veces más)<extra></extra>"
        ),
    ))
    fig.add_trace(go.Bar(
        name="Los otros diecinueve meses",
        orientation="h",
        y=canales,
        x=[100 - v for v in pico],
        marker=dict(color="#e5e7eb"),
        text=[pct(100 - v) for v in pico],
        textposition="inside",
        insidetextanchor="middle",
        textfont=dict(color=INK, size=12),
        hoverinfo="skip",
    ))

    fig.add_vline(
        x=plano,
        line=dict(color="#e4572e", dash="dot"),
        annotation_text=f"{pct(plano)} si todos los meses pesaran igual",
        annotation_position="top right",
        annotation_font=dict(size=11, color="#e4572e"),
    )

    fig.update_layout(
        title="Cuánto del periodo se juega en Black Friday y Navidad",
        barmode="stack",
        bargap=0.45,
    )
    fig.update_xaxes(ticksuffix="%", range=[0, 100], showgrid=False)
    fig.update_yaxes(showgrid=False)
    return base_layout(fig, 350, top_margin=85)


ILLUSTRATION = (
    "<br><span style='font-size:12px'>Ilustración · curva 30–90 (pico a 45); "
    "no es una medición del dataset</span>"
)


def chart_curva_madurez(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """Cuánto de las devoluciones ha aterrizado a N días tras la venta."""
    del con  # la curva es asunción pura; no lee el warehouse
    milestones = maturity_milestones()
    xs = [f"{d} días" for d, _ in milestones]
    ys = [100 * c for _, c in milestones]

    fig = go.Figure(go.Scatter(
        x=xs,
        y=ys,
        mode="lines+markers+text",
        line=dict(color=INK, width=2.5),
        marker=dict(size=9),
        text=[pct(y, 0) if y >= 1 else pct(y, 1) for y in ys],
        textposition="top center",
        hovertemplate="%{x}: %{y:.0f}% de las devoluciones ya aterrizadas<extra></extra>",
    ))
    fig.update_layout(title="Curva declarada de llegada de devoluciones" + ILLUSTRATION)
    fig.update_yaxes(ticksuffix="%", range=[0, 110], title_text="% acumulado")
    return base_layout(fig, 360, top_margin=95)


def chart_mismo_mes(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """La mentira (mes de venta que se reescribe) frente a la defendida (caja)."""
    rewrite = sketch_sale_month_rewrite(con)
    sale_in, debits = sketch_sale_month_stable_and_debits(con)

    fig = make_subplots(
        rows=1,
        cols=2,
        subplot_titles=(
            "As-of report date · el mes de venta se reescribe",
            "As-of return date · la venta no se toca",
        ),
        horizontal_spacing=0.08,
        column_widths=[0.48, 0.52],
    )

    fig.add_trace(go.Scatter(
        name="Neto del mes de venta",
        x=[d.strftime("%d/%m/%Y") for d, _ in rewrite],
        y=[v for _, v in rewrite],
        mode="lines+markers",
        line=dict(color="#e4572e", width=2.5),
        marker=dict(size=8),
        hovertemplate="Visto el %{x}: %{y:,.0f} €<extra></extra>",
    ), row=1, col=1)

    # Panel derecho: ingreso de ventas del mes (plano) + barras de débitos en meses posteriores.
    labels = [SKETCH_SALE_MONTH.strftime("%m/%Y") + " ventas"] + [
        m.strftime("%m/%Y") for m, _ in debits
    ]
    values = [sale_in] + [-v for _, v in debits]
    colors = ["#1f2933"] + ["#e4572e"] * len(debits)
    fig.add_trace(go.Bar(
        name="Caja del mes",
        x=labels,
        y=values,
        marker=dict(color=colors),
        text=[eur(abs(v)) for v in values],
        textposition="outside",
        hovertemplate="%{x}: %{y:,.0f} €<extra></extra>",
        showlegend=False,
    ), row=1, col=2)

    fig.update_layout(
        title=(
            f"Enero 2025 visto de dos formas"
            f"{ILLUSTRATION}"
        ),
        showlegend=False,
    )
    fig.update_yaxes(tickformat=",.0f", ticksuffix=" €", row=1, col=1)
    fig.update_yaxes(tickformat=",.0f", ticksuffix=" €", row=1, col=2)
    fig.update_xaxes(tickangle=-30, row=1, col=2)
    return base_layout(fig, 420, top_margin=120, bottom_margin=40)


def chart_caja_mensual(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """Serie de caja: ventas del mes menos devoluciones que aterrizan en el mes."""
    series = [
        (month, cash_net, partial)
        for month, cash_net, partial in cash_monthly_series(con)
        if not partial
    ]

    fig = go.Figure()
    fig.add_trace(go.Scatter(
        name="Ingreso neto de caja",
        x=[month for month, _, _ in series],
        y=[cash_net for _, cash_net, _ in series],
        mode="lines",
        line=dict(color=INK, width=2.5),
        hovertemplate="%{x|%m/%Y}: %{y:,.0f} € de caja neta<extra></extra>",
    ))
    fig.update_layout(
        title=(
            "Ingreso neto a fecha de devolución · flujo de caja mensual"
            "<br><span style='font-size:12px'>Una devolución entra una vez, en el"
            " mes en que ocurre; los meses anteriores no se reescriben</span>"
        ),
        showlegend=False,
    )
    fig.update_yaxes(tickformat=",.0f", ticksuffix=" €", rangemode="tozero")
    fig.update_xaxes(tickformat="%m/%Y", dtick="M3")
    return base_layout(fig, 400, top_margin=95)


# Los cuatro tramos en que se parte un euro de ingreso neto, con el indice de
# columna que ocupan en los marts de contribucion y el color de su etiqueta.
CM_LAYERS = (
    ("Coste de producto", 2, "#64748b", "white"),
    ("Transporte imputado", 3, "#cbd5e1", INK),
    ("Coste de devolución", 4, "#e4572e", "white"),
    ("Contribución", 5, "#111827", "white"),
)


def chart_cm_stack(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """Los eslabones que van del ingreso neto a la contribución, canal a canal.

    La altura de cada barra es el ingreso neto: las cuatro secciones son el
    reparto exacto de ese euro. Solo llevan etiqueta dentro las dos grandes: la
    devolucion es tan fina (1.433 € sobre 1,78 M en wholesale) que su texto solo
    cabria pisando al vecino.
    """
    rows = con.sql("""
        select channel, net_revenue, product_cost, shipping_cost_allocated,
               return_shipping_cost, contribution_margin, cm_pct
        from rpt_channel_contribution
        where channel <> 'TODOS'
        order by net_revenue desc
    """).fetchall()

    channels = [r[0] for r in rows]
    fig = go.Figure()
    labelled = {"Coste de producto", "Contribución"}
    for name, idx, color, text_color in CM_LAYERS:
        share = [100.0 * float(r[idx]) / float(r[1]) for r in rows]
        fig.add_trace(go.Bar(
            name=name,
            x=channels,
            y=[float(r[idx]) for r in rows],
            marker_color=color,
            text=[eur(r[idx]) if name in labelled else "" for r in rows],
            textposition="inside",
            insidetextanchor="middle",
            textfont=dict(color=text_color, size=12),
            customdata=share,
            hovertemplate=(
                "%{x} · " + name
                + ": %{y:,.0f} € (%{customdata:.1f}% del ingreso neto)<extra></extra>"
            ),
        ))

    for channel, row in zip(channels, rows):
        fig.add_annotation(
            x=channel,
            y=float(row[1]),
            text=f"{eur(row[1])}<br><b>CM {pct(row[6])}</b>",
            showarrow=False,
            yshift=22,
            font=dict(size=12),
        )

    fig.update_layout(
        barmode="stack",
        bargap=0.45,
        # Sin esto plotly encoge la etiqueta hasta hacerla ilegible en marketplace;
        # mejor que desaparezca y quede el hover.
        uniformtext=dict(minsize=10, mode="hide"),
        title=(
            "De ingreso neto a contribución: los eslabones del coste, canal a canal"
            "<br><span style='font-size:12px'>Cada barra es el ingreso neto del canal"
            " repartido en sus cuatro tramos</span>"
        ),
    )
    fig.update_yaxes(
        tickformat=",.0f", ticksuffix=" €", rangemode="tozero",
        range=[0, max(float(r[1]) for r in rows) * 1.16],
    )
    return base_layout(fig, 460, top_margin=105)


def chart_cm_canales(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """CM% del dato original frente al escenario realista D-18."""
    rows = con.sql("""
        select channel, cm_pct, cm_scenario_pct
        from rpt_channel_contribution
        where channel <> 'TODOS'
        order by cm_pct desc
    """).fetchall()

    channels = [r[0] for r in rows]
    fig = go.Figure()
    fig.add_trace(go.Bar(
        name="CM con datos originales",
        x=channels,
        y=[float(r[1]) for r in rows],
        marker_color=[COLORS[c] for c in channels],
        opacity=0.9,
        text=[pct(r[1]) for r in rows],
        textposition="outside",
        textfont=dict(size=11),
        hovertemplate="%{x}: %{y:.1f}%<extra>datos originales</extra>",
    ))
    fig.add_trace(go.Bar(
        name="CM con escenario realista",
        x=channels,
        y=[float(r[2]) for r in rows],
        marker_color=[COLORS[c] for c in channels],
        opacity=0.45,
        # Wholesale se va a negativo con el escenario: signo tipografico, no guion.
        text=[pct(r[2]).replace("-", "−") for r in rows],
        textposition="outside",
        textfont=dict(size=11),
        hovertemplate="%{x}: %{y:.1f}%<extra>escenario realista</extra>",
    ))
    fig.update_layout(
        barmode="group",
        bargap=0.35,
        title=(
            "Margen % por canal: datos originales frente al escenario realista"
            "<br><span style='font-size:12px'>Escenario: wholesale factura al 45%"
            " del PVP y marketplace paga un 17,5% de comisión</span>"
        ),
        yaxis_title="CM %",
    )
    fig.update_yaxes(ticksuffix="%", zeroline=True, zerolinecolor="#dfe3e8")
    return base_layout(fig, 440, top_margin=105)


def chart_cm_diagnostico(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """Dos lecturas del margen: dato original y los cuatro canales al 21%."""
    rows = con.sql("""
        select channel, cm_pct, cm_tax_equalized_pct
        from rpt_channel_contribution
        where channel <> 'TODOS'
        order by cm_pct desc
    """).fetchall()

    channels = [r[0] for r in rows]
    fig = go.Figure()
    series = [
        ("Datos originales", 1, 1.0),
        ("IVA igualado al 21%", 2, 0.45),
    ]
    for name, idx, opacity in series:
        fig.add_trace(go.Bar(
            name=name,
            x=channels,
            y=[float(r[idx]) for r in rows],
            marker_color=[COLORS[c] for c in channels],
            opacity=opacity,
            text=[pct(r[idx]) for r in rows],
            textposition="outside",
            textfont=dict(size=11),
            hovertemplate="%{x} · " + name + ": %{y:.1f}%<extra></extra>",
        ))
    fig.update_layout(
        barmode="group",
        bargap=0.35,
        title="Igualando el impuesto, la ventaja de wholesale se reduce a la mitad",
        yaxis_title="CM %",
    )
    fig.update_yaxes(ticksuffix="%", range=[0, 62])
    return base_layout(fig, 420, top_margin=60)


def chart_cm_categorias(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """El mismo euro de ingreso repartido dentro de cada categoría.

    Se pasan los euros del mart y plotly normaliza cada columna al 100%
    (`barnorm`): asi el reparto no se calcula aqui. El orden es el CM%: de
    peor a mejor margen, para que la seccion negra crezca de izquierda a
    derecha.
    """
    rows = con.sql("""
        select category, net_revenue, product_cost, shipping_cost_allocated,
               return_shipping_cost, contribution_margin,
               shipping_pct_of_net, cm_pct
        from rpt_category_contribution
        order by cm_pct
    """).fetchall()

    categories = [r[0] for r in rows]
    fig = go.Figure()
    labelled = {"Coste de producto", "Transporte imputado", "Contribución"}
    for name, idx, color, text_color in CM_LAYERS:
        share = [100.0 * float(r[idx]) / float(r[1]) for r in rows]
        fig.add_trace(go.Bar(
            name=name,
            x=categories,
            y=[float(r[idx]) for r in rows],
            marker_color=color,
            text=[pct(s) if name in labelled else "" for s in share],
            textposition="inside",
            insidetextanchor="middle",
            textfont=dict(color=text_color, size=11),
            customdata=[(float(r[idx]), s) for r, s in zip(rows, share)],
            hovertemplate=(
                "%{x} · " + name
                + ": %{customdata[1]:.2f}% del ingreso neto"
                + " (%{customdata[0]:,.0f} €)<extra></extra>"
            ),
        ))

    fig.update_layout(
        barmode="stack",
        barnorm="percent",
        bargap=0.35,
        uniformtext=dict(minsize=10, mode="hide"),
        title=(
            "Margen de contribución por categoría: de Accessories (31,7%) a"
            " Shoes (40,2%)"
            "<br><span style='font-size:12px'>Cada columna es el 100% del ingreso"
            " neto; la sección negra es el margen. Ordenadas de peor a mejor"
            " CM%</span>"
        ),
    )
    fig.update_yaxes(ticksuffix="%", range=[0, 100])
    return base_layout(fig, 460, top_margin=105)


def chart_cm_productos(con: duckdb.DuckDBPyConnection) -> go.Figure:
    """Rank de ingreso vs rank de CM: lo que parece sano y se cae."""
    rows = con.sql("""
        select product_name, category, revenue_rank, cm_rank,
               net_revenue, contribution_margin, cm_pct
        from rpt_product_contribution
        where revenue_rank <= 30
        order by revenue_rank
    """).fetchall()

    fig = go.Figure()
    # Diagonal: mismo puesto en ingreso y en CM.
    fig.add_trace(go.Scatter(
        x=[1, 30], y=[1, 30],
        mode="lines",
        line=dict(color="#dfe3e8", width=1, dash="dot"),
        hoverinfo="skip",
        showlegend=False,
    ))
    fig.add_trace(go.Scatter(
        x=[float(r[2]) for r in rows],
        y=[float(r[3]) for r in rows],
        mode="markers",
        showlegend=False,
        marker=dict(
            size=[max(8, min(22, float(r[4]) / 8000)) for r in rows],
            # Rojo = margen bajo, verde = margen alto, pero con la barra puesta
            # del reves (55% abajo, 20% arriba) para que el rojo quede arriba.
            # Plotly no sabe invertir el eje de una colorbar, asi que se colorea
            # sobre el CM% negado y se reetiquetan los ticks en positivo.
            color=[-float(r[6]) for r in rows],
            colorscale="RdYlGn",
            reversescale=True,
            cmin=-55,
            cmax=-20,
            colorbar=dict(
                title="CM %",
                tickvals=list(range(-55, -19, 5)),
                ticktext=[f"{-v}%" for v in range(-55, -19, 5)],
            ),
            line=dict(width=0.5, color="#1f2933"),
        ),
        text=[r[0] for r in rows],
        customdata=[[r[1], eur(r[4]), eur(r[5]), pct(r[6])] for r in rows],
        hovertemplate=(
            "%{text}<br>%{customdata[0]}"
            "<br>rank ingreso %{x} · rank CM %{y}"
            "<br>ingreso %{customdata[1]} · CM %{customdata[2]} (%{customdata[3]})"
            "<extra></extra>"
        ),
    ))
    fig.update_layout(
        title="Top 30 en ingreso: por encima de la diagonal, el margen empeora el puesto",
        xaxis_title="Rank por ingreso neto (1 = más ingreso)",
        yaxis_title="Rank por contribución (1 = más CM €)",
    )
    fig.update_xaxes(range=[0.5, 31], dtick=5)
    fig.update_yaxes(range=[0.5, 70], dtick=10)
    return base_layout(fig, 480, top_margin=60)


CHARTS = {
    "escalera": chart_escalera,
    "peldanos": chart_peldanos,
    "mensual": chart_mensual,
    "yoy": chart_yoy,
    "crecimiento": chart_crecimiento,
    "devoluciones": chart_devoluciones,
    "estacionalidad": chart_estacionalidad,
    "curva_madurez": chart_curva_madurez,
    "mismo_mes": chart_mismo_mes,
    "caja_mensual": chart_caja_mensual,
    "cm_stack": chart_cm_stack,
    "cm_canales": chart_cm_canales,
    "cm_diagnostico": chart_cm_diagnostico,
    "cm_categorias": chart_cm_categorias,
    "cm_productos": chart_cm_productos,
}


# --------------------------------------------------------------------------- #
# Render
# --------------------------------------------------------------------------- #

STYLES = """
:root { --ink:#1f2933; --muted:#6b7280; --line:#e5e7eb; --accent:#2563eb; }
* { box-sizing: border-box; }
body {
  margin: 0; background: #f6f7f9; color: var(--ink);
  font-family: FONT_STACK; font-size: 17px; line-height: 1.65;
}
main { max-width: 860px; margin: 0 auto; padding: 0 24px 96px; }
header.report {
  max-width: 860px; margin: 0 auto; padding: 56px 24px 32px;
}
header.report .eyebrow {
  text-transform: uppercase; letter-spacing: .12em; font-size: 12px;
  color: var(--muted); font-weight: 600;
}
header.report h1 { font-size: 40px; line-height: 1.15; margin: 12px 0 8px; }
header.report .meta { color: var(--muted); font-size: 14px; }
section.chapter {
  background: white; border: 1px solid var(--line); border-radius: 10px;
  padding: 8px 40px 40px;
}
h1 { font-size: 30px; line-height: 1.2; margin: 32px 0 16px; }
h2 {
  font-size: 22px; margin: 44px 0 12px; padding-top: 20px;
  border-top: 1px solid var(--line);
}
h3 { font-size: 17px; margin: 28px 0 8px; color: #374151; }
p { margin: 0 0 16px; }
a { color: var(--accent); }
strong { font-weight: 650; }
blockquote {
  margin: 24px 0; padding: 14px 20px; background: #fff8e6;
  border-left: 3px solid #d97706; border-radius: 0 6px 6px 0;
}
blockquote p:last-child { margin-bottom: 0; }
h1 + blockquote {
  background: #f3f4f6; border-left-color: var(--muted);
  color: var(--muted); font-size: 15px;
}
table { width: 100%; border-collapse: collapse; margin: 24px 0; font-size: 15px; }
th, td { padding: 9px 10px; border-bottom: 1px solid var(--line); text-align: left; }
th { font-size: 13px; text-transform: uppercase; letter-spacing: .04em; color: var(--muted); }
/* La alineacion de cada columna la decide el propio markdown con `---:`. */
td { font-variant-numeric: tabular-nums; }
tbody tr:last-child td { border-bottom: none; }
ul, ol { margin: 0 0 16px; padding-left: 22px; }
li { margin-bottom: 8px; }
hr { border: none; border-top: 1px solid var(--line); margin: 40px 0; }
figure.chart { margin: 28px 0; }
pre {
  background: #f8fafc; border: 1px solid var(--line); border-radius: 8px;
  padding: 14px 16px; overflow-x: auto; font-size: 13px; line-height: 1.45;
}
code { font-size: 0.92em; }
pre code { font-size: 13px; }
/* La portada del CEO: cuatro cifras, sin gráfico. */
.kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin: 24px 0; }
.kpi { background: #f8fafc; border: 1px solid var(--line); border-radius: 8px; padding: 14px 16px; }
.kpi .value { display: block; font-size: 25px; font-weight: 650; line-height: 1.2; }
.kpi .label { display: block; font-size: 13px; color: var(--muted); margin-top: 6px; line-height: 1.35; }
@media (max-width: 700px) { .kpis { grid-template-columns: repeat(2, 1fr); } }
footer.report {
  max-width: 860px; margin: 0 auto; padding: 24px; color: var(--muted); font-size: 14px;
}
@media print {
  body { background: white; }
  section.chapter { border: none; padding: 0; }
}
""".replace("FONT_STACK", FONT)

PAGE = """<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>{styles}</style>
<script>{plotlyjs}</script>
</head>
<body>
<header class="report">
  <div class="eyebrow">Case study · Analytics Engineer</div>
  <h1>{headline}</h1>
  <div class="meta">{meta}</div>
</header>
<main>{body}</main>
<footer class="report">
  {footer}
</footer>
</body>
</html>
"""


def render_charts(html: str, con: duckdb.DuckDBPyConnection, section_name: str) -> str:
    """Sustituye los marcadores [[chart:nombre]] por su figura."""
    for name, build in CHARTS.items():
        marker = f"<p>[[chart:{name}]]</p>"
        if marker not in html:
            continue
        figure = build(con).to_html(
            full_html=False,
            include_plotlyjs=False,
            config={"displayModeBar": False, "responsive": True},
        )
        html = html.replace(marker, f'<figure class="chart">{figure}</figure>')

    if "[[chart:" in html:
        raise SystemExit(f"Hay marcadores de grafico sin definir en {section_name}")
    return html


def absolute_links(html: str) -> str:
    """Los enlaces a otros .md del repo apuntan a GitHub cuando se leen en HTML."""
    return re.sub(
        r'href="(?!https?:)([^"]+\.md)"',
        lambda match: f'href="{REPO}/{match.group(1)}"',
        html,
    )


def build_document(
    doc: Document,
    con: duckdb.DuckDBPyConnection,
    converter: markdown.Markdown,
    plotlyjs: str,
    cutoff: str,
    lines: int,
) -> Path:
    chapters = []
    for section in doc.sections:
        converter.reset()
        body = converter.convert((ROOT / section).read_text(encoding="utf-8"))
        body = absolute_links(render_charts(body, con, section))
        chapters.append(f'<section class="chapter">{body}</section>')

    output = REPORT_DIR / doc.filename
    output.write_text(
        PAGE.format(
            title=doc.title,
            headline=doc.headline,
            styles=STYLES,
            plotlyjs=plotlyjs,
            meta=(
                f"{lines:,} líneas de pedido".replace(",", ".")
                + f" · datos hasta {cutoff} · {doc.meta_suffix}"
            ),
            body="\n".join(chapters),
            footer=doc.footer,
        ),
        encoding="utf-8",
    )
    return output


def main() -> None:
    if not DATABASE.exists():
        raise SystemExit("No hay warehouse todavia. Ejecuta antes: make build")

    con = duckdb.connect(str(DATABASE), read_only=True)
    # `toc` no dibuja indice: se usa porque pone un id en cada encabezado y eso
    # permite enlazar a un apartado concreto del report. `fenced_code` para el
    # DDL y el bloque snapshot de la sección 02.
    converter = markdown.Markdown(
        extensions=["tables", "attr_list", "sane_lists", "toc", "fenced_code"]
    )
    plotlyjs = plotly.offline.get_plotlyjs()
    cutoff, lines = con.sql("""
        select strftime(max(sale_date), '%d/%m/%Y'), count(*)
        from fct_sale_line
    """).fetchone()

    for doc in DOCUMENTS:
        output = build_document(doc, con, converter, plotlyjs, cutoff, lines)
        print(f"[report] {output.relative_to(ROOT)} ({output.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Test de independencia canal x categoria y canal x metodo de envio.

Responde a una objecion concreta: mirar dos tablas de porcentajes y decir "se
parecen" no es una prueba. El chi-cuadrado convierte ese "se parecen" en un
numero: bajo la hipotesis de que el canal no influye en lo que se vende ni en
como se envia, cuanta discrepancia cabe esperar por puro azar muestral y cuanta
se observa.

Solo stdlib: la p se calcula con la gamma incompleta regularizada (Numerical
Recipes), no con scipy.

Uso:
    python3 analysis/audit/23_test_independencia.py
"""

from __future__ import annotations

import csv
import math
import pathlib

TABLAS = pathlib.Path(__file__).with_name("out") / "22_tablas_de_contingencia.csv"
ITER_MAX = 500
EPS = 1e-14


def gamma_q(a: float, x: float) -> float:
    """Gamma incompleta superior regularizada Q(a, x) = 1 - P(a, x)."""
    if x < a + 1.0:
        # Serie para P(a, x), mas estable en la cola izquierda.
        termino = suma = 1.0 / a
        for n in range(1, ITER_MAX):
            termino *= x / (a + n)
            suma += termino
            if abs(termino) < abs(suma) * EPS:
                break
        return 1.0 - suma * math.exp(-x + a * math.log(x) - math.lgamma(a))

    # Fraccion continua para Q(a, x), mas estable en la cola derecha.
    b, c = x + 1.0 - a, 1.0 / 1e-300
    d = 1.0 / b
    h = d
    for i in range(1, ITER_MAX):
        an = -i * (i - a)
        b += 2.0
        d = an * d + b
        if abs(d) < 1e-300:
            d = 1e-300
        c = b + an / c
        if abs(c) < 1e-300:
            c = 1e-300
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1.0) < EPS:
            break
    return h * math.exp(-x + a * math.log(x) - math.lgamma(a))


def p_chi2(chi2: float, gl: int) -> float:
    return gamma_q(gl / 2.0, chi2 / 2.0)


def cargar() -> dict[str, dict[str, dict[str, int]]]:
    tablas: dict[str, dict[str, dict[str, int]]] = {}
    with open(TABLAS, encoding="utf-8") as fh:
        for fila in csv.DictReader(fh):
            eje = tablas.setdefault(fila["eje"], {})
            eje.setdefault(fila["valor"], {})[fila["canal"]] = int(fila["lineas"])
    return tablas


def analizar(nombre: str, tabla: dict[str, dict[str, int]]) -> None:
    valores = sorted(tabla)
    canales = sorted({c for fila in tabla.values() for c in fila})
    obs = [[tabla[v].get(c, 0) for c in canales] for v in valores]

    total = sum(sum(f) for f in obs)
    por_valor = [sum(f) for f in obs]
    por_canal = [sum(f[j] for f in obs) for j in range(len(canales))]

    chi2 = sum(
        (obs[i][j] - por_valor[i] * por_canal[j] / total) ** 2
        / (por_valor[i] * por_canal[j] / total)
        for i in range(len(valores))
        for j in range(len(canales))
    )
    gl = (len(valores) - 1) * (len(canales) - 1)
    v_cramer = math.sqrt(chi2 / (total * (min(len(valores), len(canales)) - 1)))

    # Mayor distancia, en puntos porcentuales, entre el reparto de un canal y el
    # reparto global. Es la lectura de negocio: "ningun canal se desvia mas de X".
    peor = max(
        (
            abs(100 * obs[i][j] / por_canal[j] - 100 * por_valor[i] / total),
            valores[i],
            canales[j],
        )
        for i in range(len(valores))
        for j in range(len(canales))
    )

    print(f"== {nombre}  ({len(valores)} valores x {len(canales)} canales, n = {total:,})")
    print(f"   chi2 = {chi2:.2f}   gl = {gl}   p = {p_chi2(chi2, gl):.3f}")
    print(f"   V de Cramer = {v_cramer:.4f}")
    print(f"   desviacion maxima vs mix global = {peor[0]:.2f} pp  ({peor[2]} / {peor[1]})")
    veredicto = (
        "independientes: el canal no predice esta variable"
        if p_chi2(chi2, gl) > 0.05
        else "hay dependencia estadistica"
    )
    print(f"   veredicto: {veredicto}\n")


def main() -> None:
    for nombre, tabla in sorted(cargar().items()):
        analizar(nombre, tabla)


if __name__ == "__main__":
    main()

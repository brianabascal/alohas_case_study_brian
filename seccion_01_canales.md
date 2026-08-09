# Sección 01 — Ventas por canal

Qué va a contestar esta sección, con qué reglas y qué deja deliberadamente fuera.
Se escribe **antes** de la primera consulta para que el análisis no derive hacia
lo que resulte fácil de sacar.

Es un documento de trabajo: cuando la sección esté escrita, se archiva. El
contexto permanente sigue siendo [`decisiones.md`](decisiones.md) y
[`hallazgos_auditoria.md`](hallazgos_auditoria.md).

**La sección ya está escrita:** el texto está en
[`seccion_01_canales_report.md`](seccion_01_canales_report.md) y el report montado,
con sus gráficos, se genera con `make report` en `report/index.html`.

La pregunta del brief, literal: *"How is the business performing across channels?
What's the right time grain? Are we comparing like for like (returns, taxes,
channel mix shift)? Is one channel quietly growing while another quietly leaks?
When you show channel performance, what would a CEO want to see first — and what
would a Head of Wholesale want to see instead?"*

---

## 1. Lo que ya está decidido y aquí solo se aplica

- **El titular es el ingreso neto**, sin IVA y descontando lo devuelto
  ([D-15](decisiones.md)). Es lo que permite poner a wholesale en la misma tabla
  que los otros tres sin hacer trampa.
- **Grano mensual con comparativa contra el mismo mes del año anterior**, fechas
  convertidas a `Europe/Madrid` antes de agrupar, corte del dataset el 29 de mayo
  de 2026 ([D-17](decisiones.md)).
- **Lectura a fecha de la venta**: la devolución se atribuye al mes en que se
  vendió la prenda, no al mes en que se devolvió ([D-16](decisiones.md)).
- **El ranking se publica con su aviso.** Mide dos cosas —quién paga IVA y quién
  devuelve— y no modelos de negocio ([D-20](decisiones.md)).
- **Fuera por falta de dato**: ticket medio por pedido y prendas por cesta
  ([D-05](decisiones.md)), cualquier corte por país ([D-06](decisiones.md)), y
  cualquier métrica de cliente o de recurrencia, porque no hay identificador de
  cliente en ninguna de las tres tablas.

## 2. Lo que se decide aquí

### El periodo se parte en dos años exactos, no en 25 meses

El dataset va del 29 de mayo de 2024 al 29 de mayo de 2026, así que hay dos meses
cojos: mayo de 2024 tiene tres días de ventas y a mayo de 2026 le faltan dos. Un
mes de tres días pintado como un mes normal parece un desplome, y el último mes
parece una caída del 6% que solo existe en el calendario.

- El **crecimiento titular** se calcula sobre dos ventanas de 365 días ancladas en
  la fecha de corte: del 31-05-2025 al 30-05-2026 contra el 31-05-2024 al
  30-05-2025. El precio de comparar periodos del mismo tamaño es que los dos
  primeros días del dataset se quedan fuera de las dos ventanas: 106 líneas, el
  0,2%.
- La **serie mensual** se dibuja entera, pero esos dos meses van marcados como
  parciales y no entran en la línea de tendencia ni en ninguna comparativa.

Un detalle que aparece al pasar las fechas a hora de Barcelona: el último día con
ventas deja de ser el 29 de mayo de 2026 y pasa a ser el 30, con siete líneas
sueltas que en UTC eran de la noche anterior. No cambia nada, pero explica por qué
las ventanas terminan en día 30 y no en día 29.

### El ingreso de esta sección incluye los artículos sin ficha; el margen de la 03 no

Las 750 líneas que venden artículos fuera de catálogo son 203.240 € de ventas
reales, así que cuentan como ingreso. Pero no tienen coste, así que no pueden
entrar en el margen y salen del mart de la sección 03 ([D-09](decisiones.md)).

Consecuencia práctica: **el ingreso de la 01 y la base de la 03 no van a cuadrar
entre sí**, y la diferencia es ese 1,6%. Va escrito en el propio gráfico, porque
si no, el primero que reste las dos cifras pensará que se ha perdido dinero por
el camino.

### Marketplace no se puede leer mes a mes

Son 2.556 líneas en dos años, unas cien al mes. A ese volumen, cualquier subida o
bajada mensual es ruido de muestreo y no un movimiento del negocio. Ese canal se
lee **en trimestres o con media móvil de tres meses**, y se dice en el gráfico.
Los otros tres aguantan perfectamente el grano mensual.

### El escenario de wholesale no entra en esta sección

La 01 es la capa reportada: lo que dice el dato, cuadrando con BigQuery al
céntimo. El escenario de wholesale al 45% del precio de venta y la comisión de
marketplace del 17,5% ([D-18](decisiones.md)) son la respuesta a la pregunta 03 y
viven allí.

Lo que sí lleva la 01 es **un aviso de una línea junto al ranking**: el ingreso de
wholesale es precio de escaparate, no precio de mayorista, así que su cuota está
inflada por construcción del dato.

---

## 3. Las preguntas que esta sección se compromete a responder

### Tamaño y crecimiento

1. **¿Cuánto factura Alohas en dos años y cuánto de eso es ingreso de verdad?**
   La escalera completa: importe cobrado → sin IVA → neto de devoluciones. Cuánto
   se cae en cada peldaño y cuál es el que más se cae.
2. **¿Ha crecido el negocio, y cuánto?** Segundo año contra primero, en ingreso
   neto, sobre las dos ventanas de doce meses exactas.
3. **¿El crecimiento es de vender más o de vender más caro?** Con cero descuentos
   en dos años y precio de catálogo fijo, el precio medio solo se puede mover por
   mezcla de categorías. Separar unidades, precio medio y mezcla convierte esa
   rareza del dataset en un hallazgo en vez de dejarla como un misterio.

### ¿Comparamos peras con peras?

4. **¿Cambia el ranking de canales según el peldaño de la escalera en que lo
   mires?** Wholesale gana cuota al quitar el IVA, porque no lo paga, y vuelve a
   ganarla al descontar devoluciones, porque devuelve el 4,2% frente al 17,9% de
   online. El mismo negocio, tres rankings distintos: esa es la respuesta al
   *"are we comparing like for like"*.
5. **Por canal, ¿cuánto se evapora entre lo cobrado y el ingreso neto?** Y qué
   parte de esa evaporación es impuesto y qué parte es devolución.
6. **¿Ha cambiado la mezcla de canales en dos años?** Si el peso de cada canal se
   mueve, una parte del crecimiento del total no es crecimiento sino
   recomposición, y eso cambia qué hay que hacer al respecto.

### ¿Alguien crece en silencio y a alguien se le queda el crecimiento por el camino?

7. **¿Qué canal aporta más euros de crecimiento y cuál crece más rápido en
   porcentaje?** Casi nunca son el mismo, y confundirlos es el error clásico de
   una diapositiva de canales.
8. **¿Hay algún canal cuyo importe cobrado crece pero cuyo ingreso neto no?** Esa
   es la definición operativa de *leak*: vender más y quedarse igual porque se
   devuelve más.
9. **¿La tasa de devolución de cada canal es estable o se está deteriorando?** Es
   la única palanca de esta sección sobre la que se puede actuar el lunes
   siguiente. Se mira partiendo el periodo en cuatro medios años, no comparando dos
   años sueltos: un tramo flojo mueve el año entero y se disfraza de tendencia.
10. **¿Los cuatro canales tienen la misma estacionalidad?** El pico de noviembre y
    diciembre debería ser de los canales de consumidor final. Si wholesale también
    lo tiene, es una confirmación más de que aquí el canal es casi una etiqueta.

### Qué ve primero cada lector

11. **El CEO**: ingreso neto del último año, crecimiento contra el año anterior,
    cuánto pone cada canal y hacia dónde se mueve la mezcla. Una portada, cuatro
    números y el aviso de comparabilidad.
12. **El Head of Wholesale**: su canal contra sí mismo, nunca contra online.
    Comparar un canal B2B de 7.300 líneas con uno B2C de 30.000 no le dice nada
    que pueda usar. Lo suyo es su estacionalidad, su tasa de devolución, su mezcla
    de categorías y su precio realizado, que es justo donde el dataset le da la
    respuesta más incómoda.
13. **¿Qué le pediría cada uno a este report que el dataset no puede dar?** El CEO
    querría margen por canal —se lo damos en la 03— y algo de recurrencia de
    cliente, que no existe. El Head of Wholesale querría sell-through por cuenta y
    cartera de pedidos, y no hay ni cuenta ni pedido. Decir qué falta es parte de
    la respuesta, no una disculpa.

### La pregunta del grano, contestada con el dato delante

14. **¿Por qué mensual, y no semanal ni contra el mes anterior?** Enseñando el
    mismo periodo en tres granos se ve solo: en semanal marketplace desaparece
    bajo el ruido, y comparar enero contra diciembre en moda es medir la Navidad,
    no el negocio.

---

## 4. Lo que no entra

- **Margen y rentabilidad por canal**, incluida su evolución en el tiempo. Es la
  sección 03 y necesita el escenario completo para no engañar. La 01 cierra con
  el puente: aquí está quién crece; quién gana dinero, en la 03.
- **Cualquier mapa o corte por país**, porque el destino no es observable
  ([D-06](decisiones.md)).
- **Métricas de pedido y de cliente**, que no existen en el esquema.

---

## 5. Dónde vive cada respuesta

Los modelos están en `transform/models/`. Cada uno se construyó para un bloque de
preguntas, no como un cajón de métricas:

| Modelo | Preguntas | Qué contesta |
|---|---|---|
| `fct_sale_line` | todas | El hecho a grano de línea, con la escalera de ingresos y las etiquetas de calendario. De aquí salen también los cortes sin modelo propio, como mirar el mismo periodo en semanas para justificar el grano. |
| `rpt_channel_revenue_ladder` | 1, 4, 5 | La escalera de lo cobrado al ingreso neto, y la cuota de cada canal en tres peldaños distintos. |
| `rpt_channel_monthly` | 6, 9, 10, 14 | Serie mensual por canal con tasa de devolución, cuota del mes, media móvil y comparativa contra el año anterior. |
| `rpt_channel_growth` | 2, 3, 7, 8 | Crecimiento por canal entre las dos ventanas anuales, cuánto del crecimiento aporta cada uno y cuánto se pierde en devoluciones. |
| `rpt_channel_returns_trend` | 9 | La tasa de devolución de cada canal en cuatro medios años, que es como se distingue un deterioro de un tramo flojo. |
| `rpt_category_mix` | 3 | Si la mezcla de categorías se movió, que es lo único que puede mover el precio medio. |

Los modelos intermedios (`int_sale_line` e `int_dataset_window`) concentran las dos
reglas que gobiernan todo lo demás: la conversión horaria con la escalera de
ingresos, y los límites del dataset con sus dos ventanas anuales.

## 6. Cómo se sabrá que la sección está bien

- Un lector que solo lea la 01 sabe cuál es el canal más grande, cuál crece, a cuál
  se le quedan euros en las devoluciones, y **por qué el ranking no significa lo que
  parece**.
- Todos los números del report salen de los marts, no de consultas sueltas: el
  texto no calcula nada por su cuenta y `report/build_report.py` solo dibuja. Las
  consultas de la auditoría, que sí son exploratorias, siguen en `analysis/audit/`
  con su CSV ([E-02](decisiones.md)).
- Los cuatro tests de `transform/tests/` pasan: la escalera cuadra con el hecho,
  el mart mensual mantiene su grano y las cantidades son coherentes.
- Ninguna cifra de esta sección contradice a `hallazgos_auditoria.md`; si alguna
  lo hace, se corrige el documento que esté mal, no el que resulte más cómodo.
